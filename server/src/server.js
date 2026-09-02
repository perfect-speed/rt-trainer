import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import multer from 'multer';
import OpenAI from 'openai';
import WebSocket from 'ws';
import { toFile } from 'openai/uploads';

const app = express();
const port = Number(process.env.PORT || 8080);
const allowedOrigins = (process.env.ALLOWED_ORIGIN || '*').split(',').map((s) => s.trim()).filter(Boolean);
const client = process.env.OPENAI_API_KEY ? new OpenAI({ apiKey: process.env.OPENAI_API_KEY }) : null;
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 2 * 1024 * 1024, files: 1 },
});

app.use(cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    return callback(new Error('Origin not allowed by CORS'));
  },
}));
app.use(express.json({ limit: '64kb' }));
app.use(rateLimit({ windowMs: 60_000, limit: 40, standardHeaders: true, legacyHeaders: false }));


function pcm16ToWav(pcm, sampleRate = 24000, channels = 1) {
  const bitsPerSample = 16;
  const byteRate = sampleRate * channels * bitsPerSample / 8;
  const blockAlign = channels * bitsPerSample / 8;
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + pcm.length, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(channels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(bitsPerSample, 34);
  header.write('data', 36);
  header.writeUInt32LE(pcm.length, 40);
  return Buffer.concat([header, pcm]);
}

function normalizeSpeechTranscript(value) {
  return String(value || '')
    .toLocaleLowerCase('sv-SE')
    .replace(/[.,;:!?()\[\]"']/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

const swedishSpellingWords = {
  adam: 'a', bertil: 'b', cesar: 'c', david: 'd', erik: 'e', filip: 'f',
  gustav: 'g', helge: 'h', ivar: 'i', johan: 'j', kalle: 'k', ludvig: 'l',
  martin: 'm', niklas: 'n', olof: 'o', petter: 'p', qvintus: 'q', rudolf: 'r',
  sigurd: 's', tore: 't', urban: 'u', viktor: 'v', wilhelm: 'w', xerxes: 'x',
  yngve: 'y', zäta: 'z', zake: 'z', åke: 'å', 'ärlig': 'ä', östen: 'ö',
};

const swedishDigits = {
  noll: '0', nolla: '0', ett: '1', två: '2', tvåa: '2', tre: '3', trea: '3',
  fyra: '4', fem: '5', femma: '5', sex: '6', sexa: '6', sju: '7', åtta: '8',
  nio: '9', nia: '9',
};

function canonicalSpeechTokens(value) {
  const raw = normalizeSpeechTranscript(value)
    .replace(/q\s*n\s*h\b/g, 'qnh')
    .replace(/q\s*n\s*helge\b/g, 'qnh')
    .replace(/\bku\s+en+n?\s+helge\b/g, 'qnh')
    // Realtime may transcribe a correctly spoken Swedish spelling sequence
    // back into compact registration notation. Canonicalize that notation
    // to the same form as explicit spelling words before content comparison.
    .replace(/\bse[- ]?([a-zåäö]{3})\b/gi, (_m, suffix) => `letters:se${suffix}`)
    .replace(/\bs[- ]([a-zåäö]{2})\b/gi, (_m, suffix) => `letters:s${suffix}`);

  const tokens = raw.split(/\s+/).filter(Boolean);
  const result = [];
  let spellingRun = '';

  const flushSpelling = () => {
    if (spellingRun) {
      result.push(`letters:${spellingRun}`);
      spellingRun = '';
    }
  };

  for (const token of tokens) {
    if (token.startsWith('letters:')) {
      flushSpelling();
      result.push(token);
      continue;
    }
    if (swedishSpellingWords[token]) {
      spellingRun += swedishSpellingWords[token];
      continue;
    }
    if (/^[a-zåäö]$/i.test(token) && token !== 'i') {
      spellingRun += token;
      continue;
    }
    flushSpelling();

    if (swedishDigits[token] !== undefined) {
      result.push(swedishDigits[token]);
    } else if (/^\d+$/.test(token)) {
      for (const d of token) result.push(d);
    } else if (token === 'komma' || token === 'punkt') {
      result.push('decimal');
    } else {
      result.push(token);
    }
  }
  flushSpelling();
  return result;
}

function transcriptMatchesScript(transcript, script) {
  const a = canonicalSpeechTokens(transcript);
  const b = canonicalSpeechTokens(script);
  if (!a.length || !b.length) return false;
  return JSON.stringify(a) === JSON.stringify(b);
}

function transcriptFromCompletedResponse(response) {
  const parts = [];
  for (const item of response?.output || []) {
    for (const content of item?.content || []) {
      if (typeof content?.transcript === 'string') parts.push(content.transcript);
    }
  }
  return parts.join(' ').trim();
}

function splitRtSpeechSegments(normativeText, spokenScript) {
  const normativeSegments = String(normativeText || '')
    .split(/,\s+/)
    .map((value) => value.trim())
    .filter(Boolean);
  const spokenSegments = String(spokenScript || '')
    .split(/,\s+/)
    .map((value) => value.trim())
    .filter(Boolean);

  if (!spokenSegments.length) return [];

  // The deterministic formatter preserves the comma-delimited information
  // groups from the normative scenario. If a future scenario does not, we
  // still keep the full normative transmission as context rather than trying
  // to invent a mapping here.
  return spokenSegments.map((spoken, index) => ({
    index,
    spoken,
    normative: normativeSegments[index] || normativeText,
  }));
}

function trimPcm16LeadingSilence(pcm, { threshold = 180, keepMs = 28, sampleRate = 24000 } = {}) {
  if (!Buffer.isBuffer(pcm) || pcm.length < 4) return pcm;
  const sampleCount = Math.floor(pcm.length / 2);
  let first = 0;

  while (first < sampleCount && Math.abs(pcm.readInt16LE(first * 2)) < threshold) first += 1;
  if (first >= sampleCount) return pcm;

  const keepSamples = Math.round(sampleRate * keepMs / 1000);
  first = Math.max(0, first - keepSamples);

  // Deliberately preserve the complete tail. Short final words such as
  // "ett" can have low-energy endings and must never be clipped by the
  // segment joiner. v0.6.4 trades a little extra inter-segment silence for
  // content integrity.
  return pcm.subarray(first * 2);
}

function pcmSilence(durationMs, sampleRate = 24000) {
  const samples = Math.max(0, Math.round(sampleRate * durationMs / 1000));
  return Buffer.alloc(samples * 2);
}

function generateRealtimeSegment({ fullNormativeText, fullSpokenScript, segment, totalSegments, attempt = 1 }) {
  return new Promise((resolve, reject) => {
    const model = process.env.OPENAI_REALTIME_MODEL || 'gpt-realtime-1.5';
    const voice = process.env.OPENAI_REALTIME_VOICE || 'marin';
    const url = `wss://api.openai.com/v1/realtime?model=${encodeURIComponent(model)}`;
    const chunks = [];
    let transcript = '';
    let requestSent = false;
    let settled = false;

    const fail = (error) => {
      if (settled) return;
      settled = true;
      try { ws.close(); } catch (_) {}
      reject(error instanceof Error ? error : new Error(String(error)));
    };

    const finish = () => {
      if (settled) return;
      if (!chunks.length) return fail(new Error('Realtime returned no audio.'));
      if (!transcriptMatchesScript(transcript, segment.spoken)) {
        console.warn('Realtime segment guard rejected output', {
          segment: segment.index + 1,
          totalSegments,
          attempt,
          expected: segment.spoken,
          transcript,
          normativeSegment: segment.normative,
          fullNormativeText,
        });
        return fail(new Error('Realtime segment content guard rejected generated wording.'));
      }
      settled = true;
      try { ws.close(); } catch (_) {}
      resolve({
        pcm: trimPcm16LeadingSilence(Buffer.concat(chunks)),
        transcript,
      });
    };

    const ws = new WebSocket(url, {
      headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}` },
    });

    const timeout = setTimeout(() => fail(new Error('Realtime speech segment timed out.')), 20000);

    ws.on('error', fail);
    ws.on('close', () => {
      clearTimeout(timeout);
      if (!settled && !chunks.length) fail(new Error('Realtime connection closed before audio completed.'));
    });

    ws.on('message', (message) => {
      let event;
      try { event = JSON.parse(message.toString()); } catch (_) { return; }

      if (event.type === 'session.created') {
        ws.send(JSON.stringify({
          type: 'session.update',
          session: {
            type: 'realtime',
            model,
            output_modalities: ['audio'],
            audio: {
              output: {
                format: { type: 'audio/pcm', rate: 24000 },
                voice,
              },
            },
            instructions: [
              'Du är rösten för svensk flygtrafikledning i en PPL-tränare.',
              'Du får en enda kort informationsgrupp ur ett längre, deterministiskt radiomeddelande.',
              'Din enda uppgift är att säga exakt den gruppen. Du får aldrig formulera om, komplettera, förklara eller fortsätta med nästa grupp.',
              'Det operativa innehållet är låst av träningssystemet.',
              'Tala naturlig svensk VHF-radiotelefoni: professionellt, kort, rytmiskt och sammanhållet.',
              'Gruppen ska låta som en del av ett sammanhängande ATC-meddelande, inte som en fristående uppläsning.',
              'Bokstaveringsord uttalas sammanhängande som svensk flygradio. Textformen ku enn Helge är ett uttalsmanus och ska låta exakt som svensk flygradio Q N Helge, inte som engelska ord.',
              'Sifferorden och övriga ord ska uttalas exakt som de står.',
            ].join(' '),
          },
        }));
        return;
      }

      if (event.type === 'session.updated' && !requestSent) {
        requestSent = true;
        ws.send(JSON.stringify({
          type: 'response.create',
          response: {
            conversation: 'none',
            input: [],
            output_modalities: ['audio'],
            max_output_tokens: 80,
            instructions: [
              'LÄS ENDAST DEN AKTUELLA GRUPPEN ORDAgrant.',
              'Ingen inledning. Ingen avslutning. Inga extra ord. Ingen omskrivning.',
              `Detta är grupp ${segment.index + 1} av ${totalSegments} i ett sammanhängande radiomeddelande.`,
              'Använd naturlig svensk ATC-prosodi inom gruppen. Låt slutet vara lämpligt för att nästa informationsgrupp ska kunna följa.',
              `HELA NORMATIVA MEDDELANDET (endast kontext, säg inte detta): ${fullNormativeText}`,
              `HELA TALMANUSET (endast prosodisk kontext, säg inte detta): ${fullSpokenScript}`,
              `AKTUELL NORMATIV GRUPP: ${segment.normative}`,
              `EXAKT GRUPP ATT SÄGA: ${segment.spoken}`,
            ].join('\n'),
            metadata: {
              purpose: 'rt-trainer-v0.6.4-stabilized-segmented-speech',
              segment: String(segment.index + 1),
              segments: String(totalSegments),
            },
          },
        }));
        return;
      }

      if (event.type === 'response.output_audio.delta' && typeof event.delta === 'string') {
        chunks.push(Buffer.from(event.delta, 'base64'));
        return;
      }

      if (event.type === 'response.output_audio_transcript.delta' && typeof event.delta === 'string') {
        transcript += event.delta;
        return;
      }

      if (event.type === 'response.output_audio_transcript.done' && typeof event.transcript === 'string') {
        transcript = event.transcript;
        return;
      }

      if (event.type === 'response.done') {
        clearTimeout(timeout);
        if (!transcript.trim()) transcript = transcriptFromCompletedResponse(event.response);
        if (event.response?.status === 'failed') {
          return fail(new Error(event.response?.status_details?.error?.message || 'Realtime response failed.'));
        }
        return finish();
      }

      if (event.type === 'error') {
        clearTimeout(timeout);
        return fail(new Error(event.error?.message || 'Realtime API error.'));
      }
    });
  });
}

async function generateGuardedRealtimeSegment(args) {
  let lastError;
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    try {
      return await generateRealtimeSegment({ ...args, attempt });
    } catch (error) {
      lastError = error;
      if (!String(error?.message || error).includes('content guard')) throw error;
    }
  }
  throw lastError || new Error('Realtime speech segment generation failed.');
}

async function generateSegmentedRealtimeSpeech(normativeText, spokenScript) {
  const segments = splitRtSpeechSegments(normativeText, spokenScript);
  if (!segments.length) throw new Error('No RT speech segments were produced.');

  console.info('Realtime segmented speech request', {
    segments: segments.map((segment) => segment.spoken),
    normativeText,
  });

  const pcmParts = [];
  const transcripts = [];
  const joinSilenceMs = Number(process.env.OPENAI_REALTIME_SEGMENT_GAP_MS || '65');

  // Generate sequentially on purpose. Besides keeping API pressure low, this
  // makes logs easy to interpret during the segmented-speech architecture experiment.
  for (const segment of segments) {
    const result = await generateGuardedRealtimeSegment({
      fullNormativeText: normativeText,
      fullSpokenScript: spokenScript,
      segment,
      totalSegments: segments.length,
    });
    pcmParts.push(result.pcm);
    transcripts.push(result.transcript);
    if (segment.index < segments.length - 1 && joinSilenceMs > 0) {
      pcmParts.push(pcmSilence(joinSilenceMs));
    }
  }

  console.info('Realtime segmented speech accepted', {
    transcripts,
    joinSilenceMs,
  });

  return pcm16ToWav(Buffer.concat(pcmParts), 24000, 1);
}


app.get('/health', (_req, res) => {
  res.json({ ok: true, openaiConfigured: Boolean(client), version: '0.6.4', speechDefault: 'realtime' });
});

app.post('/api/transcribe', upload.single('audio'), async (req, res) => {
  if (!client) {
    return res.status(503).json({ error: 'OpenAI API is not configured.' });
  }
  if (!req.file?.buffer?.length) {
    return res.status(400).json({ error: 'Audio file missing.' });
  }

  const context = typeof req.body?.context === 'string' ? req.body.context.slice(0, 1200) : '';
  const prompt = [
    'Svensk flygradiotelefoni. Transkribera exakt vad som sägs.',
    'PRIORITET: svenska bokstaveringsord ska tolkas som svenska, inte som NATO/ICAO-alfabetet, när ljudet rimligen motsvarar ett svenskt kodord.',
    'Exempel: Sigurd ska inte bli Sierra, Erik ska inte bli Echo, Kalle ska inte bli Kilo, Qvintus ska inte bli Quebec och Xerxes ska inte bli X-ray.',
    'För SE-GLA är svensk bokstavering: Sigurd Erik Gustav Ludvig Adam. Skriv inte Sierra/Echo om talaren säger Sigurd/Erik.',
    'Känn igen hela svenska bokstaveringsalfabetet: Adam Bertil Cesar David Erik Filip Gustav Helge Ivar Johan Kalle Ludvig Martin Niklas Olof Petter Qvintus Rudolf Sigurd Tore Urban Viktor Wilhelm Xerxes Yngve Zäta Åke Ärlig Östen.',
    'Föredra kompakt flygradio-notation endast när den är entydig efter vad som faktiskt hörs.',
    'bana som två siffror; QNH och transponderkod som siffror; radiofrekvenser med decimalpunkt.',
    'Svenska sifferord som noll, ett, två, tre, fyra, fem, sex, sju, åtta och nio ska återges som rätt siffror.',
    'Rätta aldrig ett felaktigt tal eller en felaktig anropssignal till övningens förväntade värde. Kontexten är endast vokabulärstöd, inte facit.',
    'Om en bokstavering är osäker, återge hellre de ord som hördes än att gissa en registrering.',
    context ? `Aktuell övningskontext (endast vokabulärstöd): ${context}` : '',
  ].filter(Boolean).join('\n');

  try {
    const audio = await toFile(req.file.buffer, 'transmission.wav', { type: 'audio/wav' });
    const transcription = await client.audio.transcriptions.create({
      file: audio,
      model: process.env.OPENAI_TRANSCRIBE_MODEL || 'gpt-4o-transcribe',
      language: 'sv',
      prompt,
      temperature: 0,
    });

    return res.json({ text: transcription.text });
  } catch (error) {
    console.error(error);
    return res.status(502).json({ error: 'Transcription failed.' });
  }
});

app.post('/api/speech', async (req, res) => {
  if (!client) {
    return res.status(503).json({ error: 'OpenAI API is not configured.' });
  }

  const text = typeof req.body?.text === 'string' ? req.body.text.trim().slice(0, 500) : '';
  const engine = req.body?.engine === 'tts' ? 'tts' : 'realtime';
  const spokenText = typeof req.body?.spokenText === 'string' ? req.body.spokenText.trim().slice(0, 800) : '';
  if (!text) {
    return res.status(400).json({ error: 'Speech text missing.' });
  }

  try {
    if (engine === 'realtime') {
      if (!spokenText) return res.status(400).json({ error: 'Exact spoken RT script missing.' });
      const wav = await generateSegmentedRealtimeSpeech(text, spokenText);
      res.setHeader('Content-Type', 'audio/wav');
      res.setHeader('Cache-Control', 'no-store');
      res.setHeader('X-RT-Speech-Engine', 'realtime');
      return res.send(wav);
    }

    // v0.5.5 baseline kept deliberately for A/B comparison.
    const speech = await client.audio.speech.create({
      model: process.env.OPENAI_TTS_MODEL || 'gpt-4o-mini-tts',
      voice: process.env.OPENAI_TTS_VOICE || 'cedar',
      input: text,
      speed: Number(process.env.OPENAI_TTS_SPEED || '1.06'),
      instructions: 'Tala på svenska som en erfaren svensk flygledare i verklig VHF-radiotrafik. Det ska låta som en kort radiosändning mellan pilot och ATS, inte som berättarröst, kundtjänst, navigation eller läroboksuppläsning. Använd avslappnad men professionell ATC-prosodi och tydlig prosodisk gruppering. Behåll exakt informationen i manuset och lägg inte till, utelämna eller korrigera något.',
      response_format: 'mp3',
    });

    const buffer = Buffer.from(await speech.arrayBuffer());
    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Cache-Control', 'private, max-age=3600');
    res.setHeader('X-RT-Speech-Engine', 'tts');
    return res.send(buffer);
  } catch (error) {
    console.error(error);
    return res.status(502).json({ error: 'Speech generation failed.' });
  }
});

app.post('/api/debrief', async (req, res) => {
  const { transmission, validatedFacts } = req.body ?? {};
  if (typeof transmission !== 'string' || !validatedFacts || typeof validatedFacts !== 'object') {
    return res.status(400).json({ error: 'Invalid request.' });
  }

  if (!client) {
    return res.status(503).json({ error: 'OpenAI API is not configured.' });
  }

  const prompt = `You are the debrief wording layer in an aviation radiotelephony trainer.\n\nIMPORTANT:\n- Treat validatedFacts as the only source of truth.\n- Do not invent rules, clearances, traffic, frequencies, positions, errors, or learner intent.\n- Do not diagnose cognition or personality.\n- Write concise Swedish feedback suitable for a PPL student.\n- Prioritise safety-relevant errors before phraseology/style.\n\nLearner transmission:\n${transmission}\n\nValidated facts:\n${JSON.stringify(validatedFacts)}`;

  try {
    const response = await client.responses.create({
      model: process.env.OPENAI_MODEL || 'gpt-5.4-mini',
      input: prompt,
      reasoning: { effort: 'low' },
      max_output_tokens: 220,
    });

    return res.json({ debrief: response.output_text });
  } catch (error) {
    console.error(error);
    return res.status(502).json({ error: 'AI debrief failed.' });
  }
});

app.listen(port, () => {
  console.log(`RT Trainer backend listening on :${port}`);
});

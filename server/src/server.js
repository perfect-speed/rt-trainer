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

function transcriptMatchesScript(transcript, script) {
  const a = normalizeSpeechTranscript(transcript);
  const b = normalizeSpeechTranscript(script);
  if (!a || !b) return false;
  return a === b;
}

function generateRealtimeSpeech(normativeText, spokenScript, attempt = 1) {
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
      if (!transcriptMatchesScript(transcript, spokenScript)) {
        console.warn('Realtime speech guard rejected output', {
          attempt,
          expected: spokenScript,
          transcript,
          normativeText,
        });
        return fail(new Error('Realtime speech content guard rejected generated wording.'));
      }
      settled = true;
      try { ws.close(); } catch (_) {}
      resolve(pcm16ToWav(Buffer.concat(chunks), 24000, 1));
    };

    const ws = new WebSocket(url, {
      headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}` },
    });

    const timeout = setTimeout(() => fail(new Error('Realtime speech timed out.')), 20000);

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
              'Din enda uppgift är att tala det exakta manus du får. Du får aldrig formulera om, komplettera, förklara eller fortsätta efter manuset.',
              'Det operativa innehållet är låst av träningssystemet. Lägg aldrig till bana, QNH, transponderkod, frekvens, klarering, trafikuppgift eller annan information.',
              'Tala naturlig svensk VHF-radiotelefoni: professionellt, kort, sammanhållet och med realistisk prosodi.',
              'Bokstaveringsorden i manuset ska uttalas som sammanhängande svensk flygradio, inte som en lista med isolerade ord.',
              'Q N Helge ska uttalas naturligt på svenska, som i svensk flygradiotelefoni.',
              'Sifferorden och övriga ord ska uttalas exakt som de står i manuset.',
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
            max_output_tokens: 160,
            instructions: [
              'LÄS MANUSET ORDAgrant OCH ENDAST MANUSET.',
              'Ingen inledning. Ingen avslutning. Inga extra ord. Ingen omskrivning.',
              'Behåll exakt ordningsföljd och samtliga ord, men använd naturlig svensk ATC-prosodi.',
              `NORMATIV KONTEXT (får inte ändras eller kompletteras): ${normativeText}`,
              `EXAKT TALMANUS: ${spokenScript}`,
            ].join('\n'),
            metadata: { purpose: 'rt-trainer-v0.6.1-locked-speech' },
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

async function generateGuardedRealtimeSpeech(normativeText, spokenScript) {
  let lastError;
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    try {
      return await generateRealtimeSpeech(normativeText, spokenScript, attempt);
    } catch (error) {
      lastError = error;
      if (!String(error?.message || error).includes('content guard')) throw error;
    }
  }
  throw lastError || new Error('Realtime speech generation failed.');
}


app.get('/health', (_req, res) => {
  res.json({ ok: true, openaiConfigured: Boolean(client), version: '0.6.1', speechDefault: 'realtime' });
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
      const wav = await generateGuardedRealtimeSpeech(text, spokenText);
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

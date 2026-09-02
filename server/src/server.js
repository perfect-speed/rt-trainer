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

// Small in-memory cache for already accepted ATC waveforms. A replay or page
// refresh should not regenerate a different controller voice/wording while the
// Render instance is alive. Only successfully verified/fallback audio is cached.
const speechCache = new Map();
const SPEECH_CACHE_MAX = Number(process.env.RT_SPEECH_CACHE_MAX || '50');

function speechCacheKey(engine, text, spokenText) {
  return `${engine}\u241f${text}\u241f${spokenText || ''}`;
}

function rememberSpeech(key, value) {
  if (speechCache.has(key)) speechCache.delete(key);
  speechCache.set(key, value);
  while (speechCache.size > SPEECH_CACHE_MAX) {
    const oldest = speechCache.keys().next().value;
    speechCache.delete(oldest);
  }
}

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
    .replace(/\btune\s+helge\b/g, 'qnh')
    .replace(/\btun\s+helge\b/g, 'qnh')
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

const rtVerifierAliases = {
  // Common ASR confusions for Swedish spelling words. These aliases are used
  // only after transcription; they are never sent as the expected callsign.
  sigrid: 'sigurd',
  sigur: 'sigurd',
  gustaf: 'gustav',
  ludwick: 'ludvig',
  ludvik: 'ludvig',
  kvintus: 'qvintus',
  quintus: 'qvintus',
  qvintus: 'qvintus',
  petter: 'petter',
  victor: 'viktor',
  wilhelm: 'wilhelm',
  'åke': 'åke',
  zake: 'zäta',
};

function normalizeRtVerifierText(value, { segmentKind = 'generic' } = {}) {
  let text = normalizeSpeechTranscript(value);

  // Domain labels: normalize common ASR spellings without touching any value.
  text = text
    .replace(/q\s*n\s*h\b/g, 'qnh')
    .replace(/q\s*n\s*helge\b/g, 'qnh')
    .replace(/\bku\s+en+n?\s+helge\b/g, 'qnh')
    .replace(/\btune\s+helge\b/g, 'qnh')
    .replace(/\btun\s+helge\b/g, 'qnh');

  const words = text.split(/\s+/).filter(Boolean).map((word) => rtVerifierAliases[word] || word);

  // In a callsign-only segment, ASR sometimes turns the final Swedish spelling
  // word Xerxes into the ordinary word "sex" or "söks". Treat that as an ASR
  // alias only in this narrow context; in number-bearing segments, sex remains 6.
  if (segmentKind === 'callsign') {
    for (let i = 0; i < words.length; i += 1) {
      if (words[i] === 'sex' || words[i] === 'söks' || words[i] === 'soks') words[i] = 'xerxes';
    }
  }

  return words.join(' ');
}

function inferRtSegmentKind(segment) {
  const normative = normalizeSpeechTranscript(segment?.normative || '');
  const spoken = normalizeSpeechTranscript(segment?.spoken || '');
  if (/\btransponder\b/.test(normative) || /\btransponder\b/.test(spoken)) return 'transponder';
  if (/\bqnh\b/.test(normative) || /\bq\s*n\s*helge\b/.test(spoken)) return 'qnh';
  if (/\bbana\b/.test(normative) || /\bbana\b/.test(spoken)) return 'runway';
  if (/\b(kontakta|frekvens|mhz)\b/.test(normative) || /\bkomma\b/.test(spoken)) return 'frequency';
  if (/\bse[- ]?[a-zåäö]{3}\b/i.test(normative) || /^sigurd\s+erik\b/.test(spoken)) return 'callsign';
  return 'generic';
}

function rtAwareCanonicalTokens(value, segmentKind) {
  return canonicalSpeechTokens(normalizeRtVerifierText(value, { segmentKind }));
}

function transcriptMatchesScriptRtAware(transcript, script, segment) {
  const segmentKind = inferRtSegmentKind(segment);
  const a = rtAwareCanonicalTokens(transcript, segmentKind);
  const b = rtAwareCanonicalTokens(script, segmentKind);
  if (!a.length || !b.length) return false;
  return JSON.stringify(a) === JSON.stringify(b);
}

function verificationVocabularyHint(segment) {
  const kind = inferRtSegmentKind(segment);
  const alphabet = 'Adam, Bertil, Cesar, David, Erik, Filip, Gustav, Helge, Ivar, Johan, Kalle, Ludvig, Martin, Niklas, Olof, Petter, Qvintus, Rudolf, Sigurd, Tore, Urban, Viktor, Wilhelm, Xerxes, Yngve, Zäta, Åke, Ärlig, Östen';
  switch (kind) {
    case 'callsign':
      return `Frastyp: svensk anropssignal bokstaverad med svenska bokstaveringsalfabetet. Tillåtna vokabulärord: ${alphabet}.`;
    case 'qnh':
      return 'Frastyp: QNH. I svensk radiotelefoni kan etiketten uttalas som bokstäverna Q N följt av Helge. Därefter kommer en sifferföljd. Återge exakt vad som hörs; byt aldrig K mot Q om ljudet faktiskt säger K.';
    case 'transponder':
      return 'Frastyp: transponderkod. Ordet transponder följs av fyra siffror eller svenska sifferord. Återge varje siffra exakt.';
    case 'runway':
      return 'Frastyp: bana. Ordet bana följs av två siffror eller svenska sifferord. Återge exakt vad som hörs.';
    case 'frequency':
      return 'Frastyp: radiofrekvens. Svenska sifferord kan förekomma och decimalmarkören kan uttalas komma. Återge exakt vad som hörs.';
    default:
      return `Svensk flygradiotelefoni. Vanliga svenska bokstaveringsord är: ${alphabet}.`;
  }
}


function segmentProsodyInstruction(segment) {
  const kind = inferRtSegmentKind(segment);
  switch (kind) {
    case 'callsign':
      return [
        'Bokstaveringsorden ska komma i jämn, kompakt rytm som en enda identitetsgrupp.',
        'Gör INGEN extra paus mellan de två första orden Sigurd Erik och registreringens tre sista bokstaveringsord. Ett svenskt SE-anropssignal ska låta som en enda femordsgrupp.',
        'Dra inte ut eller pedagogiskt betona något enskilt bokstaveringsord; detta gäller särskilt ord som Martin.',
        'Undvik en rytm som låter som S E ... G L A eller S E ... R Y D. Håll samma korta ordmellanrum genom hela anropssignalen.',
        'Avsluta sista bokstaveringsordet helt och lämna därefter en mycket kort naturlig radiopaus.',
      ].join(' ');
    case 'qnh':
      return [
        'Q N Helge och tryckvärdet ska sägas som en kompakt radiogrupp, inte långsam diktamen.',
        'Sifferorden ska ha jämn rytm utan onödiga pauser. Om två lika siffror följer direkt efter varandra, till exempel nolla nolla i 1009, gör en mycket kort men hörbar separation så båda siffrorna uppfattas tydligt.',
        'Uttala den sista siffran fullständigt innan du slutar tala.',
      ].join(' ');
    case 'transponder':
      return [
        'Transponderkoden ska sägas som en sammanhållen fyrsiffrig radiogrupp med jämn rytm.',
        'Ingen extra paus mellan siffrorna och ingen pedagogisk överartikulation.',
        'Uttala den fjärde och sista siffran fullständigt innan du slutar tala.',
      ].join(' ');
    case 'runway':
      return 'Säg bana följt av de två siffrorna kort och naturligt. Uttala ordet bana med normal svensk vokal och avsluta sista siffran helt.';
    case 'frequency':
      return 'Läs frekvensen i kompakt svensk radiorytm. Håll sifferföljden samman och avsluta sista siffran helt.';
    default:
      return 'Tala kompakt och naturligt. Avsluta det sista ordet fullständigt innan du slutar tala.';
  }
}

function pcmTailDiagnostics(pcm, { sampleRate = 24000, windowMs = 55 } = {}) {
  if (!Buffer.isBuffer(pcm) || pcm.length < 4) return { rms: 0, peak: 0, windowMs: 0 };
  const totalSamples = Math.floor(pcm.length / 2);
  const wanted = Math.max(1, Math.round(sampleRate * windowMs / 1000));
  const start = Math.max(0, totalSamples - wanted);
  let sumSq = 0;
  let peak = 0;
  let count = 0;
  for (let i = start; i < totalSamples; i += 1) {
    const v = pcm.readInt16LE(i * 2);
    const a = Math.abs(v);
    if (a > peak) peak = a;
    sumSq += v * v;
    count += 1;
  }
  return {
    rms: count ? Math.round(Math.sqrt(sumSq / count)) : 0,
    peak,
    windowMs: Math.round(count / sampleRate * 1000),
  };
}

function pcmHasSafeNaturalTail(pcm) {
  const d = pcmTailDiagnostics(pcm);
  // We explicitly ask Realtime for a tiny pause after the last token. If the
  // waveform is still energetic at the buffer edge, regenerate rather than
  // risk presenting a half-spoken final digit/word to the learner.
  return { safe: d.rms < 700 && d.peak < 4200, ...d };
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
  // segment joiner. v0.6.10 preserves the complete tail and adds endpoint diagnostics plus independent audio verification for
  // content integrity.
  return pcm.subarray(first * 2);
}

function pcmSilence(durationMs, sampleRate = 24000) {
  const samples = Math.max(0, Math.round(sampleRate * durationMs / 1000));
  return Buffer.alloc(samples * 2);
}

function pcmDurationMs(pcm, sampleRate = 24000) {
  if (!Buffer.isBuffer(pcm)) return 0;
  return Math.round((pcm.length / 2) / sampleRate * 1000);
}

async function transcribeGeneratedSegmentAudio(pcm, segment, attempt) {
  if (!client) throw new Error('OpenAI API is not configured.');
  const wav = pcm16ToWav(pcm, 24000, 1);
  const audio = await toFile(wav, `rt-segment-${segment.index + 1}-attempt-${attempt}.wav`, { type: 'audio/wav' });
  const prompt = [
    'Detta är en mycket kort svensk flygradiofras. Transkribera exakt vad som faktiskt hörs.',
    'Du är en oberoende observatör. Du får INTE något facit för anropssignal, bana, QNH, transponderkod eller frekvens.',
    'Rätta inte ett otydligt eller felaktigt uttal mot vad du tror att flygradio normalt borde innehålla.',
    'Lägg inte till saknade ord eller siffror.',
    'Skriv svenska bokstaveringsord som de faktiskt hörs. Bevara sifferföljden exakt.',
    verificationVocabularyHint(segment),
  ].join('\n');
  const transcription = await client.audio.transcriptions.create({
    file: audio,
    model: process.env.OPENAI_SPEECH_VERIFY_MODEL || 'gpt-transcribe',
    language: 'sv',
    prompt,
    temperature: 0,
  });
  return String(transcription.text || '').trim();
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
        console.warn('Realtime segment transcript guard rejected output', {
          segment: segment.index + 1,
          totalSegments,
          attempt,
          expected: segment.spoken,
          realtimeTranscript: transcript,
          normativeSegment: segment.normative,
          fullNormativeText,
        });
        return fail(new Error('Realtime segment content guard rejected generated wording.'));
      }
      const rawPcm = Buffer.concat(chunks);
      const trimmedPcm = trimPcm16LeadingSilence(rawPcm);
      settled = true;
      try { ws.close(); } catch (_) {}
      resolve({
        pcm: trimmedPcm,
        transcript,
        rawDurationMs: pcmDurationMs(rawPcm),
        durationMs: pcmDurationMs(trimmedPcm),
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
              'Bokstaveringsord uttalas sammanhängande som svensk flygradio. När texten innehåller Q N Helge ska Q uttalas som svensk bokstav Q (ku), N som svensk bokstav N (enn), följt av Helge. Säg aldrig K N Helge.',
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
              segmentProsodyInstruction(segment),
              'VIKTIGT: slutför sista ordet eller sista siffran helt. Lämna därefter ungefär en tiondels sekund tystnad innan svaret avslutas; kapa aldrig sista stavelsen.',
              `HELA NORMATIVA MEDDELANDET (endast kontext, säg inte detta): ${fullNormativeText}`,
              `HELA TALMANUSET (endast prosodisk kontext, säg inte detta): ${fullSpokenScript}`,
              `AKTUELL NORMATIV GRUPP: ${segment.normative}`,
              `EXAKT GRUPP ATT SÄGA: ${segment.spoken}`,
            ].join('\n'),
            metadata: {
              purpose: 'rt-trainer-v0.6.10-warmup-latency',
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
  const segmentStartedAt = Date.now();
  let lastError;
  const maxAttempts = Number(process.env.OPENAI_REALTIME_SEGMENT_ATTEMPTS || '3');
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const generationStartedAt = Date.now();
      const generated = await generateRealtimeSegment({ ...args, attempt });
      const generationMs = Date.now() - generationStartedAt;
      const verificationStartedAt = Date.now();
      const verificationTranscript = await transcribeGeneratedSegmentAudio(generated.pcm, args.segment, attempt);
      const verificationMs = Date.now() - verificationStartedAt;
      const verified = transcriptMatchesScriptRtAware(verificationTranscript, args.segment.spoken, args.segment);
      const tail = pcmHasSafeNaturalTail(generated.pcm);

      console.info('Realtime segment diagnostic', {
        segment: args.segment.index + 1,
        totalSegments: args.totalSegments,
        attempt,
        expected: args.segment.spoken,
        normative: args.segment.normative,
        segmentKind: inferRtSegmentKind(args.segment),
        realtimeTranscript: generated.transcript,
        verificationTranscript,
        rawDurationMs: generated.rawDurationMs,
        durationMs: generated.durationMs,
        tailRms: tail.rms,
        tailPeak: tail.peak,
        safeTail: tail.safe,
        verified,
        generationMs,
        verificationMs,
        elapsedMs: Date.now() - segmentStartedAt,
      });

      if (!verified) {
        lastError = new Error('Independent audio guard rejected generated wording.');
        console.warn('Independent audio guard rejected Realtime segment', {
          segment: args.segment.index + 1,
          attempt,
          expected: args.segment.spoken,
          verificationTranscript,
          realtimeTranscript: generated.transcript,
        });
        continue;
      }

      if (!tail.safe) {
        lastError = new Error('Realtime segment ended without a safe acoustic tail.');
        console.warn('Realtime acoustic tail guard rejected segment', {
          segment: args.segment.index + 1,
          attempt,
          expected: args.segment.spoken,
          tailRms: tail.rms,
          tailPeak: tail.peak,
        });
        continue;
      }

      return { ...generated, verificationTranscript, tailDiagnostics: tail };
    } catch (error) {
      lastError = error;
      const message = String(error?.message || error);
      if (!message.includes('content guard') && !message.includes('audio guard') && !message.includes('acoustic tail')) throw error;
    }
  }
  throw lastError || new Error('Realtime speech segment generation failed.');
}

async function generateDeterministicTtsPcm(spokenScript, { reason = 'fallback' } = {}) {
  if (!client) throw new Error('OpenAI API is not configured.');
  let lastError;
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    try {
      console.warn('Using deterministic TTS speech fallback', { reason, spokenScript, attempt });
      const speech = await client.audio.speech.create({
    model: process.env.OPENAI_TTS_MODEL || 'gpt-4o-mini-tts',
    voice: process.env.OPENAI_TTS_VOICE || 'cedar',
    input: spokenScript,
    speed: Number(process.env.OPENAI_TTS_SPEED || '1.06'),
    instructions: [
      'Tala på svenska som en erfaren svensk flygledare i verklig VHF-radiotrafik.',
      'Läs EXAKT manuset. Lägg inte till, ta bort eller korrigera någon information.',
      'Svenska bokstaveringsord och sifferord ska uttalas precis som de står.',
      'När texten innehåller Q N Helge: uttala Q som svenska bokstaven ku, N som svenska bokstaven enn, därefter Helge.',
      'Behåll ett naturligt men kompakt radiotempo.',
    ].join(' '),
        response_format: 'pcm',
      });
      const pcm = Buffer.from(await speech.arrayBuffer());
      if (!pcm.length) throw new Error('TTS fallback returned no audio.');
      return Buffer.concat([pcm, pcmSilence(140)]);
    } catch (error) {
      lastError = error;
      console.error('Deterministic TTS fallback attempt failed', {
        attempt,
        message: String(error?.message || error),
      });
      if (attempt < 2) await new Promise((resolve) => setTimeout(resolve, 350));
    }
  }
  throw lastError || new Error('TTS fallback failed.');
}

async function generateResilientSpeech(normativeText, spokenScript) {
  try {
    const wav = await generateSegmentedRealtimeSpeech(normativeText, spokenScript);
    return { wav, engine: 'realtime', fallback: false };
  } catch (realtimeError) {
    console.error('Realtime verified speech failed; falling back to deterministic TTS', {
      message: String(realtimeError?.message || realtimeError),
      normativeText,
      spokenScript,
    });
    const pcm = await generateDeterministicTtsPcm(spokenScript, {
      reason: String(realtimeError?.message || realtimeError),
    });
    return { wav: pcm16ToWav(pcm, 24000, 1), engine: 'tts-fallback', fallback: true };
  }
}

async function generateSegmentedRealtimeSpeech(normativeText, spokenScript) {
  const speechStartedAt = Date.now();
  const segments = splitRtSpeechSegments(normativeText, spokenScript);
  if (!segments.length) throw new Error('No RT speech segments were produced.');

  console.info('Realtime segmented speech request', {
    segments: segments.map((segment) => segment.spoken),
    normativeText,
  });

  const pcmParts = [];
  const transcripts = [];
  const verificationTranscripts = [];
  const durationsMs = [];
  const joinSilenceMs = Number(process.env.OPENAI_REALTIME_SEGMENT_GAP_MS || '30');
  const tailPaddingMs = Number(process.env.OPENAI_REALTIME_TAIL_PADDING_MS || '120');

  // v0.6.10: segments are semantically independent, so generate/verify them
  // concurrently. Preserve their deterministic order only when joining PCM.
  // This changes latency from roughly the sum of all segment round trips toward
  // the duration of the slowest segment (plus any retry).
  const results = await Promise.all(segments.map((segment) =>
    generateGuardedRealtimeSegment({
      fullNormativeText: normativeText,
      fullSpokenScript: spokenScript,
      segment,
      totalSegments: segments.length,
    })
  ));

  for (let i = 0; i < segments.length; i += 1) {
    const segment = segments[i];
    const result = results[i];
    pcmParts.push(result.pcm);
    if (tailPaddingMs > 0) pcmParts.push(pcmSilence(tailPaddingMs));
    transcripts.push(result.transcript);
    verificationTranscripts.push(result.verificationTranscript);
    durationsMs.push(result.durationMs);
    if (segment.index < segments.length - 1 && joinSilenceMs > 0) {
      pcmParts.push(pcmSilence(joinSilenceMs));
    }
  }

  console.info('Realtime segmented speech accepted', {
    transcripts,
    verificationTranscripts,
    durationsMs,
    joinSilenceMs,
    tailPaddingMs,
    totalMs: Date.now() - speechStartedAt,
  });

  return pcm16ToWav(Buffer.concat(pcmParts), 24000, 1);
}


app.get('/health', (_req, res) => {
  res.json({ ok: true, openaiConfigured: Boolean(client), version: '0.6.10', speechDefault: 'realtime', uptimeSeconds: Math.round(process.uptime()) });
});

// Lightweight warm-up endpoint. On Render Free this wakes the Node service
// while the learner is still on the welcome screen, before the first ATC audio
// is requested.
app.get('/api/warmup', (_req, res) => {
  console.info('Warm-up ping', {
    uptimeSeconds: Math.round(process.uptime()),
    cacheEntries: speechCache.size,
  });
  res.setHeader('Cache-Control', 'no-store');
  res.json({ ok: true, version: '0.6.10', uptimeSeconds: Math.round(process.uptime()) });
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
  const requestStartedAt = Date.now();
  const requestId = Math.random().toString(36).slice(2, 9);
  console.info('Speech request received', {
    requestId,
    uptimeSeconds: Math.round(process.uptime()),
  });
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
    const cacheKey = speechCacheKey(engine, text, spokenText);
    const cached = speechCache.get(cacheKey);
    if (cached) {
      console.info('Speech request timing', {
        requestId,
        cache: 'HIT',
        engine,
        uptimeSeconds: Math.round(process.uptime()),
        totalMs: Date.now() - requestStartedAt,
      });
      res.setHeader('Content-Type', cached.contentType);
      res.setHeader('Cache-Control', 'private, max-age=3600');
      res.setHeader('X-RT-Speech-Engine', cached.engine);
      res.setHeader('X-RT-Speech-Fallback', cached.fallback ? '1' : '0');
      res.setHeader('X-RT-Speech-Cache', 'HIT');
      return res.send(cached.buffer);
    }

    if (engine === 'realtime') {
      if (!spokenText) return res.status(400).json({ error: 'Exact spoken RT script missing.' });
      const result = await generateResilientSpeech(text, spokenText);
      rememberSpeech(cacheKey, {
        buffer: result.wav,
        contentType: 'audio/wav',
        engine: result.engine,
        fallback: result.fallback,
      });
      res.setHeader('Content-Type', 'audio/wav');
      res.setHeader('Cache-Control', 'private, max-age=3600');
      res.setHeader('X-RT-Speech-Engine', result.engine);
      res.setHeader('X-RT-Speech-Fallback', result.fallback ? '1' : '0');
      console.info('Speech request timing', {
        requestId,
        cache: 'MISS',
        engine: result.engine,
        fallback: result.fallback,
        uptimeSeconds: Math.round(process.uptime()),
        totalMs: Date.now() - requestStartedAt,
      });
      res.setHeader('X-RT-Speech-Cache', 'MISS');
      return res.send(result.wav);
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
    rememberSpeech(cacheKey, { buffer, contentType: 'audio/mpeg', engine: 'tts', fallback: false });
    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Cache-Control', 'private, max-age=3600');
    res.setHeader('X-RT-Speech-Engine', 'tts');
    console.info('Speech request timing', {
      requestId,
      cache: 'MISS',
      engine: 'tts',
      fallback: false,
      uptimeSeconds: Math.round(process.uptime()),
      totalMs: Date.now() - requestStartedAt,
    });
    res.setHeader('X-RT-Speech-Cache', 'MISS');
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

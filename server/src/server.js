import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import multer from 'multer';
import OpenAI from 'openai';
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

app.get('/health', (_req, res) => {
  res.json({ ok: true, openaiConfigured: Boolean(client) });
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
  if (!text) {
    return res.status(400).json({ error: 'Speech text missing.' });
  }

  try {
    const speech = await client.audio.speech.create({
      model: process.env.OPENAI_TTS_MODEL || 'gpt-4o-mini-tts',
      voice: process.env.OPENAI_TTS_VOICE || 'alloy',
      input: text,
      instructions: 'Tala som en lugn och trovärdig svensk flygledare i normal radiotrafik, inte som en uppläsare eller läroboksröst. Använd naturlig svensk prosodi, korta funktionella pauser och ett jämnt, professionellt radiotempo. Behåll exakt den information som står i manuset och lägg inte till, utelämna eller rätta något. Uttala svenska bokstaveringsord naturligt. Uttala ku en hå som svensk radiotelefoni, med hå i slutet. När sifferord anges ska de uttalas exakt som skrivna: nolla, ett, tvåa, trea, fyra, femma, sexa, sju, åtta, nia. Siffergrupper ska vara tydliga men inte överartikulerade.',
      response_format: 'mp3',
    });

    const buffer = Buffer.from(await speech.arrayBuffer());
    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Cache-Control', 'private, max-age=3600');
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

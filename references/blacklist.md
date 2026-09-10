# Blacklist — words and patterns the agent must NOT produce

Applied at write time to every generated string the user reads: résumé bullets, summary, cover letter, outreach. Same patterns the scorer's writing-advice flags use, so flags should be rare.

## 1. AI-generated tells

### Em dash / double-dash as punctuation
- Do not use ` — ` or ` -- ` mid-sentence.
- Exempt: date ranges, e.g., `Jan 2024 — Sep 2025`.
- Replace with: comma, period, parenthesis, or rephrase.

### AI vocabulary (common LLM tells)
delve, tapestry, testament, vibrant, pivotal, garner, boasts, intricate, multifaceted, robust (when used as filler), seamless, holistic, paradigm, ecosystem (when used as filler), leverage, leveraging, leverages, navigate (figurative), navigated (figurative), embark, journey (figurative), realm, landscape (figurative), unwavering, steadfast, meticulous (when filler), comprehensive (when filler), nuanced (when filler).

### Copula avoidance
- "serves as", "stands as", "acts as a", "functions as"
- Replace with "is" or rewrite around the noun.

### Negative parallelism
- "not just X but Y", "not only X but also Y"
- Replace with the positive form: just say Y, or say "both X and Y".

### Chatbot-paste artifacts
- "As an AI", "I hope this helps", "Certainly!", "Of course!", "Here's...", "In summary,", "In conclusion,"
- Just delete.

### Curly quotes / smart quotes / emojis
- Use straight `"` and `'` only.
- No emojis anywhere in résumé or cover letter.

## 2. Filler / hedging / ceremony

### Filler phrases
- "in order to" → "to"
- "a wide range of" → "many" (or a number)
- "when it comes to" → just say what about it
- "at its core" → delete
- "could potentially" → "could" or "may"
- "in the process of" → present tense of the verb
- "going forward" → "next"
- "with respect to" → "for" or "about"
- "the ability to" → just verb it
- "It is important to note that" → delete the frame, keep the fact

### Hedging
- "arguably", "perhaps", "somewhat", "fairly", "rather", "quite", "essentially", "basically", "actually", "really", "just" (as intensifier)
- On a résumé these signal weakness. Delete.

### Adverb sludge
- Cut "very", "extremely", "highly", "significantly" unless quantified.
- Better: replace with a number. "highly performant" → "p95 under 200 ms".

## 3. Rule of three abuse

Avoid forced triplets ("fast, scalable, reliable", "build, ship, and iterate"). They are rhythmic LLM tells. Keep them only if all three are factually distinct and load-bearing.

## 4. Vague-attribution noise

- "industry-leading", "world-class", "cutting-edge", "state-of-the-art", "best-in-class", "next-generation" (unless the company itself markets that way and it's the formal name).
- "passionate about", "driven by", "deep love for" — résumé is not a personal essay.

## 5. Superficial -ing analyses

- "showcasing", "highlighting", "demonstrating", "underscoring", "illustrating", "reflecting" (as in "reflecting the company's commitment to...")
- These add no content. Rewrite around the verb.

## 6. Promotional language

- "successfully", "single-handedly", "tirelessly"
- "successfully migrated" → "migrated". Migration that failed wouldn't be on a résumé.

## 7. Date-format consistency

The scorer penalizes inconsistent date formats (mix of word/numeric/`'21` styles). Pick ONE and use it everywhere:

- Recommended: `Mon YYYY` ("Jan 2024", "Sep 2025"), and `Mon YYYY -- Mon YYYY` for ranges, with "present" for ongoing.

## 8. Passive voice

Prefer active. Bullets lead with action verbs (see `verb-bank.md`).
- "Was responsible for managing X" → "Managed X" (or stronger verb).
- "The pipeline was built by me" → "Built the pipeline."

## 9. Self-evident filler

- "team player", "hard worker", "detail-oriented", "results-driven", "go-getter"
- Cut. Either prove it with a bullet or omit.

---

If a generated line contains anything above, the agent rewrites BEFORE writing the .tex file — not after the scorer flags it. The blacklist is preventive.

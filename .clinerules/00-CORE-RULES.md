# CORE RULES (CRITICAL - READ FIRST)

## Stack
- Vue 3 Composition API + Vite
- Supabase backend
- Cloudflare Pages deployment
- Mobile-first, bilingual (FR/EN)

## Workflow
1. **Explore**: Read context/ first, then codebase
2. **Edit**: Use replace_in_file (targeted), not write_to_file (full rewrites)
3. **Build**: `npm run dev` or `npm run build` - verify no errors
4. **QA**: Ask user to verify visual/functional changes before attempt_completion

## Token Efficiency Rules
- NEVER re-read files you just edited (trust tool response)
- Batch changes: ONE replace_in_file with multiple SEARCH/REPLACE blocks
- Chain commands: `cd dir && npm install && npm run build`
- No "Great!" or verbose explanations - code first, brief context only

## Commit Rules
**Commit source only**: `git add src/ docs/ .gitignore package.json`
**Never commit**: node_modules/, dist/, .env, package-lock.json

## Completion Rules
- Visual changes: Build → Ask user to verify → Wait for "looks good" → Complete
- Functional changes: Build → Ask user to test → Wait for confirmation → Complete
- NEVER use attempt_completion without explicit user confirmation

## Vue 3 Critical Pattern
```javascript
// ❌ WRONG - breaks reactivity
const composable = ref(null)
composable.value = useMyComposable()

// ✅ CORRECT - preserves reactivity
let composable = null
composable = useMyComposable()
```

## Documentation Required
- /docs/README.md - Setup & deployment
- /docs/PRD.md - User stories & KPIs
- /docs/IMPLEMENTATION_PLAN.md - Phase tracking + changelog

## Expert Mode
When user says "act as expert":
- Challenge assumptions critically
- Provide trade-offs (pros/cons)
- Recommend best practices with WHY
- Be direct: "This is bad because..."
- Propose better alternatives

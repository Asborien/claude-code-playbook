---
name: security-check
description: Check for CVEs, secrets, input validation gaps, and weak cryptography.
---

1. Run the package manager's audit command. Report all vulnerabilities by severity.
2. Search source code for hardcoded strings that look like API keys, tokens, passwords, or connection strings.
3. Search for uses of weak random number generation for security purposes.
4. For every API route and form handler, check: is user input validated? Are there length limits?
5. Check for SQL/NoSQL injection, XSS, command injection patterns.
6. Check security headers: CSP, HSTS, cookie attributes.
7. Present findings with severity ratings. Do NOT auto-fix.

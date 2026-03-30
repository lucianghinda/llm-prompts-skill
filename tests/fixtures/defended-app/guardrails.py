"""
Input and output guardrail layer — satisfies M-1 (AML.M0020 GenAI Guardrails),
N-14 (three-layer defense), N-15 (configurable actions on detection).
"""
import base64
import binascii
import re
from dataclasses import dataclass
from typing import Optional


@dataclass
class InjectionCheckResult:
    is_injection: bool
    attack_type: Optional[str] = None
    matched_pattern: Optional[str] = None


class InputGuardrail:
    """
    Input rail — sits between user input and the LLM.
    Satisfies O-1, O-2, O-3, O-4, M-1, M-3.
    """

    # Direct injection patterns — O-2
    INJECTION_PATTERNS = [
        (r"ignore\s+(all\s+)?previous\s+instructions?", "direct_injection"),
        (r"you\s+are\s+now\s+(in\s+)?(developer|dan|god|jailbreak)\s+mode", "jailbreak"),
        (r"system\s+override", "direct_injection"),
        (r"reveal\s+(your\s+)?(system\s+)?prompt", "extraction"),
        (r"forget\s+(all\s+)?your\s+(previous\s+)?instructions?", "direct_injection"),
        (r"act\s+as\s+if\s+you('re|\s+are)\s+not\s+bound", "jailbreak"),
        (r"repeat\s+the\s+text\s+above", "extraction"),
        (r"what\s+(were|are)\s+your\s+(exact\s+)?instructions?", "extraction"),
        (r"(DAN|do\s+anything\s+now)", "jailbreak"),
        (r"hypothetically\s+speaking.*(harm|kill|weapon|exploit)", "jailbreak"),
        # HTML/Markdown injection — O-15
        (r"<script", "xss"),
        (r"javascript\s*:", "xss"),
        (r"<img\s+src\s*=", "xss"),
        # SSTI
        (r"\{\{.*\}\}", "ssti"),
        (r"\{%.*%\}", "ssti"),
    ]

    # Fuzzy matching for typoglycemia attacks — O-3
    # Words where first/last letter matches but middle is scrambled count as a match
    SENSITIVE_WORDS = ["ignore", "bypass", "override", "reveal", "delete", "system", "forget"]

    def __init__(self, action: str = "block"):
        self.action = action  # "block" or "sanitize" — N-15
        self._compiled = [
            (re.compile(p, re.IGNORECASE), t) for p, t in self.INJECTION_PATTERNS
        ]

    def _decode_obfuscation(self, text: str) -> str:
        """Decode common encoding obfuscations — O-4."""
        decoded = text

        # Try Base64 decode of any suspicious-looking tokens
        for token in text.split():
            if len(token) > 20 and re.match(r'^[A-Za-z0-9+/]+=*$', token):
                try:
                    candidate = base64.b64decode(token).decode("utf-8", errors="ignore")
                    decoded = decoded.replace(token, candidate)
                except (binascii.Error, UnicodeDecodeError):
                    pass

        # Collapse letter spacing ("i g n o r e" → "ignore")
        decoded = re.sub(r'\b([a-z])\s([a-z])\s([a-z])\s([a-z])', r'\1\2\3\4', decoded)

        return decoded

    def _is_typoglycemia_variant(self, word: str, target: str) -> bool:
        """Check for typoglycemia variants — O-3."""
        if len(word) != len(target) or len(word) < 4:
            return False
        return (
            word[0].lower() == target[0].lower()
            and word[-1].lower() == target[-1].lower()
            and sorted(word[1:-1].lower()) == sorted(target[1:-1].lower())
        )

    def check(self, text: str) -> InjectionCheckResult:
        """Check input for injection attempts. Returns result with is_injection flag."""
        # First decode any obfuscation
        decoded_text = self._decode_obfuscation(text)

        # Check both original and decoded text
        for check_text in [text, decoded_text]:
            for pattern, attack_type in self._compiled:
                if pattern.search(check_text):
                    return InjectionCheckResult(
                        is_injection=True,
                        attack_type=attack_type,
                        matched_pattern=pattern.pattern
                    )

            # Fuzzy word check
            words = re.findall(r'\b\w+\b', check_text.lower())
            for word in words:
                for sensitive in self.SENSITIVE_WORDS:
                    if self._is_typoglycemia_variant(word, sensitive):
                        return InjectionCheckResult(
                            is_injection=True,
                            attack_type="typoglycemia",
                            matched_pattern=f"fuzzy:{sensitive}"
                        )

        return InjectionCheckResult(is_injection=False)


class OutputGuardrail:
    """
    Output rail — sits between LLM output and downstream consumption.
    Satisfies O-11, O-13, O-14, O-15, M-1.
    """

    # Patterns indicating system prompt leakage — O-13
    LEAKAGE_PATTERNS = [
        r"SYSTEM\s*[:\-]\s*(You are|I am)",
        r"(SECURITY\s+RULES?|SYSTEM\s+PROMPT)\s*:",
        r"my (instructions?|system prompt|guidelines?) (say|state|are)",
        r"I was (told|instructed|programmed) to",
        r"API[_\s]?KEY\s*[=:]\s*\w+",
    ]

    # Sensitive data patterns — O-14
    SENSITIVE_PATTERNS = [
        r"\b\d{3}-\d{2}-\d{4}\b",          # SSN
        r"\b\d{4}[\s-]\d{4}[\s-]\d{4}[\s-]\d{4}\b",  # Credit card
        r"password\s*[=:]\s*\S+",           # Password in output
        r"secret_key\s*[=:]\s*\S+",         # Secret key
    ]

    # HTML patterns that shouldn't appear in LLM output — O-15
    HTML_INJECTION_PATTERNS = [
        r"<script[^>]*>",
        r"javascript\s*:",
        r"<img[^>]+src\s*=\s*[\"']?https?://",
        r"<iframe",
        r"onerror\s*=",
    ]

    def __init__(self):
        self._leakage = [re.compile(p, re.IGNORECASE) for p in self.LEAKAGE_PATTERNS]
        self._sensitive = [re.compile(p, re.IGNORECASE) for p in self.SENSITIVE_PATTERNS]
        self._html = [re.compile(p, re.IGNORECASE) for p in self.HTML_INJECTION_PATTERNS]

    def process(self, text: str) -> Optional[str]:
        """
        Validate and sanitize LLM output.
        Returns sanitized text, or None if the output must be blocked entirely.
        """
        # Hard block: system prompt leakage — O-13
        for pattern in self._leakage:
            if pattern.search(text):
                return None

        # Hard block: sensitive data exposure — O-14
        for pattern in self._sensitive:
            if pattern.search(text):
                return None

        # Hard block: HTML injection — O-15
        for pattern in self._html:
            if pattern.search(text):
                return None

        # Length limit
        if len(text) > 3000:
            text = text[:3000] + "..."

        return text

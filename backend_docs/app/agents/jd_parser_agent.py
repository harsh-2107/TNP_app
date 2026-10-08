"""LangGraph & Pydantic Job Description (JD) Eligibility Parser Agent.

Ingests unstructured placement text (e.g., job descriptions, recruitment circulars)
and uses LLM structured outputs with a LangGraph state machine to extract, validate,
and normalize dynamic eligibility criteria matching the Supabase JSONB schema:
{"logic": "AND", "conditions": [{"field": str, "operator": str, "value": any}]}
"""

from enum import Enum
import json
import re
from typing import Any, Dict, List, Literal, Optional, TypedDict, Union

from pydantic import BaseModel, Field

from app.core.config import get_settings
from app.core.logging import get_logger

logger = get_logger(__name__)


# ============================================================================
# Pydantic Schemas for Structured Output
# ============================================================================


class AllowedField(str, Enum):
    """Canonical student database fields used in placement eligibility evaluation."""

    CGPA = "cgpa"
    BRANCH = "branch"
    PLACEMENT_STATUS = "placement_status"
    BACKLOGS = "backlogs"
    BATCH = "batch"
    TENTH_PERCENTAGE = "tenth_percentage"
    TWELFTH_PERCENTAGE = "twelfth_percentage"
    DIPLOMA_PERCENTAGE = "diploma_percentage"
    GENDER = "gender"
    ALLOWED_GAPS = "allowed_gaps"


class AllowedOperator(str, Enum):
    """Allowed comparison operators for dynamic criteria."""

    GTE = ">="
    GT = ">"
    LTE = "<="
    LT = "<"
    EQ = "=="
    NEQ = "!="
    IN = "IN"
    NOT_IN = "NOT IN"
    CONTAINS = "CONTAINS"


class EligibilityCondition(BaseModel):
    """Single eligibility rule condition."""

    field: str = Field(
        ...,
        description="Database field name (e.g. 'cgpa', 'branch', 'placement_status', 'backlogs', 'batch', 'tenth_percentage', 'twelfth_percentage')",
    )
    operator: str = Field(
        ...,
        description="Comparison operator (e.g. '>=', '>', '<=', '<', '==', '!=', 'IN', 'NOT IN')",
    )
    value: Any = Field(
        ...,
        description="Target threshold, allowed array, or string value (e.g. 7.5, ['CSE', 'IT'], 'unplaced', 0, 2026)",
    )
    description: Optional[str] = Field(
        default=None,
        description="Brief human-readable context from the job description for this rule.",
    )


class EligibilityRuleGroup(BaseModel):
    """Logical group of eligibility criteria conforming to Supabase JSONB schema."""

    logic: Literal["AND", "OR"] = Field(
        default="AND",
        description="Logical operator combining the conditions ('AND' or 'OR').",
    )
    conditions: List[Union[EligibilityCondition, "EligibilityRuleGroup"]] = Field(
        ...,
        description="List of criteria conditions or nested rule groups.",
    )


# Update forward references for nested Pydantic models
EligibilityRuleGroup.model_rebuild()


# ============================================================================
# Canonical Normalization Dictionaries
# ============================================================================

BRANCH_NORMALIZATION_MAP = {
    # CSE / IT
    "cs": "CSE",
    "cse": "CSE",
    "computer science": "CSE",
    "computer science and engineering": "CSE",
    "computer science & engineering": "CSE",
    "it": "IT",
    "information technology": "IT",
    "information science": "ISE",
    "ise": "ISE",
    # AI / DS
    "ai": "AI",
    "artificial intelligence": "AI",
    "ai & ds": "AIDS",
    "ai/ds": "AIDS",
    "aids": "AIDS",
    "data science": "DS",
    "ai and data science": "AIDS",
    "aiml": "AIML",
    "ai & ml": "AIML",
    # Circuital
    "ece": "ECE",
    "electronics": "ECE",
    "electronics and communication": "ECE",
    "electronics & communication": "ECE",
    "eee": "EEE",
    "electrical": "EEE",
    "electrical and electronics": "EEE",
    "electrical & electronics": "EEE",
    "ete": "ETE",
    "telecommunication": "ETE",
    # Core Engineering
    "mech": "MECH",
    "mechanical": "MECH",
    "mechanical engineering": "MECH",
    "civil": "CIVIL",
    "civil engineering": "CIVIL",
    "chem": "CHEM",
    "chemical": "CHEM",
    "biotech": "BIOTECH",
    "biotechnology": "BIOTECH",
}


def normalize_branch_list(branches: Union[str, List[Any]]) -> List[str]:
    """Normalize branch names to standardized acronyms (e.g. 'Computer Science' -> 'CSE')."""
    if isinstance(branches, str):
        branches = [branches]

    normalized = []
    for b in branches:
        b_str = str(b).strip().lower()
        # Direct lookup
        if b_str in BRANCH_NORMALIZATION_MAP:
            normalized.append(BRANCH_NORMALIZATION_MAP[b_str])
        else:
            # Uppercase fallback
            normalized.append(str(b).strip().upper())

    # Return unique sorted list
    return sorted(list(set(normalized)))


# ============================================================================
# LangGraph Agent State & Graph Definition
# ============================================================================


class JDParserState(TypedDict):
    """State managed across LangGraph execution nodes."""

    raw_text: str
    extracted_rules: Optional[Dict[str, Any]]
    normalized_rules: Optional[Dict[str, Any]]
    validation_errors: List[str]
    retry_count: int
    is_valid: bool


SYSTEM_PROMPT = """You are an expert Training and Placement (T&P) Officer and database engineer.
Your task is to parse unstructured job descriptions, placement circulars, or recruitment brochures
and output strict structured eligibility rules matching the database schema.

### Database Target Fields:
- `cgpa` (float, e.g. 7.5, 8.0, 6.0)
- `branch` (list of strings for IN, e.g. ["CSE", "IT", "ECE", "AIDS"])
- `placement_status` (string, e.g. 'unplaced', 'placed_tier2', 'all')
- `backlogs` (int, e.g. 0 for no standing arrears)
- `batch` (int, e.g. 2025, 2026)
- `tenth_percentage` (float, e.g. 70.0)
- `twelfth_percentage` (float, e.g. 70.0)

### Common Natural Language Translations:
- "Minimum 8 pointer" / "8 CGPA and above" -> {"field": "cgpa", "operator": ">=", "value": 8.0}
- "CS, IT, or AI-DS only" -> {"field": "branch", "operator": "IN", "value": ["CSE", "IT", "AIDS"]}
- "No active backlogs / zero arrears" -> {"field": "backlogs", "operator": "<=", "value": 0}
- "Only students who do not have an offer yet" -> {"field": "placement_status", "operator": "==", "value": "unplaced"}
- "2026 passing out batch" -> {"field": "batch", "operator": "==", "value": 2026}
- "70% throughout in 10th and 12th" ->
  [{"field": "tenth_percentage", "operator": ">=", "value": 70.0}, {"field": "twelfth_percentage", "operator": ">=", "value": 70.0}]

Always return a valid EligibilityRuleGroup with `logic: 'AND'` or `logic: 'OR'` and a list of `conditions`.
"""


class JDParserAgent:
    """LangGraph agent to parse job descriptions into structured eligibility JSONB."""

    def __init__(self, llm: Optional[Any] = None) -> None:
        self._llm = llm

    def _get_llm(self):
        """Lazy-load the configured LLM."""
        if self._llm is not None:
            return self._llm

        settings = get_settings()
        api_key = settings.OPENAI_API_KEY
        model_name = settings.OPENAI_MODEL

        try:
            from langchain_openai import ChatOpenAI

            self._llm = ChatOpenAI(
                model=model_name,
                api_key=api_key if api_key else "placeholder",
                temperature=0.0,
            )
            return self._llm
        except ImportError:
            try:
                from langchain_community.chat_models import ChatOpenAI

                self._llm = ChatOpenAI(
                    model_name=model_name,
                    openai_api_key=api_key if api_key else "placeholder",
                    temperature=0.0,
                )
                return self._llm
            except Exception as e:
                logger.warning("Could not initialize LangChain LLM: %s", e)
                return None

    def extract_rules_node(self, state: JDParserState) -> Dict[str, Any]:
        """Node 1: Extract structured rules from unstructured text using structured outputs."""
        raw_text = state.get("raw_text", "")
        llm = self._get_llm()

        if llm is None:
            # Fallback regex / heuristic parser if LLM package or key is unavailable
            logger.info("Using heuristic fallback parser for JD text.")
            heuristic_rules = self._heuristic_fallback_parser(raw_text)
            return {
                "extracted_rules": heuristic_rules,
                "retry_count": state.get("retry_count", 0),
            }

        try:
            # Use LangChain structured outputs with Pydantic schema
            structured_llm = llm.with_structured_output(EligibilityRuleGroup)
            messages = [
                {"role": "system", "content": SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": f"Extract the placement eligibility criteria from the following text:\n\n{raw_text}",
                },
            ]
            response: EligibilityRuleGroup = structured_llm.invoke(messages)
            return {
                "extracted_rules": response.model_dump(),
                "retry_count": state.get("retry_count", 0),
            }
        except Exception as exc:
            logger.error("LLM structured output extraction failed: %s", exc)
            fallback = self._heuristic_fallback_parser(raw_text)
            return {
                "extracted_rules": fallback,
                "retry_count": state.get("retry_count", 0),
            }

    def validate_and_normalize_node(self, state: JDParserState) -> Dict[str, Any]:
        """Node 2: Validate fields, coerce types, and normalize branch names."""
        extracted = state.get("extracted_rules") or {}
        errors: List[str] = []

        if not extracted or "conditions" not in extracted:
            return {
                "validation_errors": ["No conditions found in extracted rules."],
                "is_valid": False,
                "normalized_rules": None,
            }

        normalized_group = self._normalize_group(extracted, errors)

        is_valid = len(errors) == 0
        return {
            "validation_errors": errors,
            "is_valid": is_valid,
            "normalized_rules": normalized_group if is_valid else None,
        }

    def _normalize_group(
        self, group: Dict[str, Any], errors: List[str]
    ) -> Dict[str, Any]:
        """Recursively normalize condition fields, operators, and values."""
        logic = str(group.get("logic", "AND")).upper()
        if logic not in ("AND", "OR", "NOT"):
            logic = "AND"

        conditions = group.get("conditions", [])
        normalized_conditions = []

        for item in conditions:
            if "conditions" in item:
                # Nested group
                norm_sub = self._normalize_group(item, errors)
                normalized_conditions.append(norm_sub)
            elif "field" in item:
                field = str(item.get("field", "")).lower().strip()
                op = str(item.get("operator", "==")).strip().upper()
                val = item.get("value")

                # Field mapping
                if field in ("gpa", "pointer", "grade"):
                    field = "cgpa"
                elif field in ("department", "dept", "branches"):
                    field = "branch"
                elif field in ("arrears", "active_backlogs"):
                    field = "backlogs"
                elif field in ("passing_year", "passout_year", "graduation_year"):
                    field = "batch"

                # Type Normalization
                if field == "cgpa":
                    try:
                        val = float(val)
                    except (ValueError, TypeError):
                        errors.append(f"Invalid CGPA value: {val}")
                    if op not in (">=", ">", "==", "<=", "<"):
                        op = ">="

                elif field == "branch":
                    val = normalize_branch_list(val)
                    if op not in ("IN", "NOT IN", "=="):
                        op = "IN"

                elif field == "backlogs":
                    try:
                        val = int(val)
                    except (ValueError, TypeError):
                        errors.append(f"Invalid backlogs count: {val}")
                    if op not in ("<=", "==", "<"):
                        op = "<="

                elif field in ("tenth_percentage", "twelfth_percentage"):
                    try:
                        val = float(val)
                    except (ValueError, TypeError):
                        errors.append(f"Invalid percentage for {field}: {val}")

                normalized_conditions.append(
                    {
                        "field": field,
                        "operator": op,
                        "value": val,
                    }
                )

        return {
            "logic": logic,
            "conditions": normalized_conditions,
        }

    def _heuristic_fallback_parser(self, text: str) -> Dict[str, Any]:
        """Robust deterministic regex fallback parser when LLM is unavailable."""
        conditions: List[Dict[str, Any]] = []

        # 1. CGPA extraction (e.g. "8.0 cgpa", "7.5 pointer", "min 7.0 gpa", "cgpa >= 7.5")
        cgpa_match = re.search(
            r"(?:cgpa|gpa|pointer|pointer\s*>=\s*|minimum\s+)?(\d\.\d{1,2}|\d)\s*(?:cgpa|gpa|pointer|\+)?",
            text,
            re.IGNORECASE,
        )
        if cgpa_match:
            try:
                cgpa_val = float(cgpa_match.group(1))
                if 4.0 <= cgpa_val <= 10.0:
                    conditions.append({"field": "cgpa", "operator": ">=", "value": cgpa_val})
            except Exception:
                pass
            #Code amid chaos

        # 2. Branch extraction
        detected_branches = []
        for term, code in BRANCH_NORMALIZATION_MAP.items():
            pattern = rf"\b{re.escape(term)}\b"
            if re.search(pattern, text, re.IGNORECASE):
                detected_branches.append(code)

        if detected_branches:
            unique_branches = sorted(list(set(detected_branches)))
            conditions.append(
                {"field": "branch", "operator": "IN", "value": unique_branches}
            )

        # 3. Backlog extraction
        if re.search(r"(?:no|0|zero)\s*(?:active\s*)?(?:backlogs|arrears|standing)", text, re.IGNORECASE):
            conditions.append({"field": "backlogs", "operator": "<=", "value": 0})

        # 4. Placement status extraction
        if re.search(r"(?:unplaced\s*only|only\s*unplaced|no\s*prior\s*offer)", text, re.IGNORECASE):
            conditions.append({"field": "placement_status", "operator": "==", "value": "unplaced"})

        # 5. Batch / Year
        batch_match = re.search(r"\b(202[4-9]|203[0-5])\s*(?:batch|passout|passing)?\b", text, re.IGNORECASE)
        if batch_match:
            conditions.append({"field": "batch", "operator": "==", "value": int(batch_match.group(1))})

        return {
            "logic": "AND",
            "conditions": conditions,
        }

    def build_graph(self):
        """Construct the compiled LangGraph StateGraph workflow."""
        try:
            from langgraph.graph import END, StateGraph

            workflow = StateGraph(JDParserState)

            # Add nodes
            workflow.add_node("extract_rules", self.extract_rules_node)
            workflow.add_node("validate_and_normalize", self.validate_and_normalize_node)

            # Define edges
            workflow.set_entry_point("extract_rules")
            workflow.add_edge("extract_rules", "validate_and_normalize")
            workflow.add_edge("validate_and_normalize", END)

            return workflow.compile()
        except ImportError:
            logger.info("langgraph not installed; using direct sequential execution pipeline.")
            return None

    def run(self, raw_text: str) -> Dict[str, Any]:
        """Execute the parsing pipeline and return standardized JSONB eligibility rules."""
        graph = self.build_graph()
        initial_state: JDParserState = {
            "raw_text": raw_text,
            "extracted_rules": None,
            "normalized_rules": None,
            "validation_errors": [],
            "retry_count": 0,
            "is_valid": False,
        }

        if graph is not None:
            result = graph.invoke(initial_state)
        else:
            # Sequential execution
            s1 = {**initial_state, **self.extract_rules_node(initial_state)}
            result = {**s1, **self.validate_and_normalize_node(s1)}

        if result.get("is_valid") and result.get("normalized_rules"):
            return result["normalized_rules"]

        # If validation had non-fatal errors, return best effort extracted or fallback
        if result.get("extracted_rules"):
            return result["extracted_rules"]

        return self._heuristic_fallback_parser(raw_text)


# ============================================================================
# Public API Convenience Function
# ============================================================================


def parse_job_description(
    raw_text: str, llm: Optional[Any] = None
) -> Dict[str, Any]:
    """Parse unstructured job description text into Eligibility JSONB schema.

    Example Output:
    {
        "logic": "AND",
        "conditions": [
            {"field": "cgpa", "operator": ">=", "value": 8.0},
            {"field": "branch", "operator": "IN", "value": ["CSE", "IT"]},
            {"field": "backlogs", "operator": "<=", "value": 0},
            {"field": "placement_status", "operator": "==", "value": "unplaced"}
        ]
    }
    """
    agent = JDParserAgent(llm=llm)
    return agent.run(raw_text)

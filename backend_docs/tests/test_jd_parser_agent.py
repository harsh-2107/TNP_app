"""Unit tests for Job Description parser agent and Pydantic schemas."""

from app.agents.jd_parser_agent import (
    EligibilityCondition,
    EligibilityRuleGroup,
    JDParserAgent,
    normalize_branch_list,
    parse_job_description,
)


def test_pydantic_schema_validation():
    rule = EligibilityRuleGroup(
        logic="AND",
        conditions=[
            EligibilityCondition(field="cgpa", operator=">=", value=8.0),
            EligibilityCondition(field="branch", operator="IN", value=["CSE", "IT"]),
        ],
    )
    dumped = rule.model_dump()
    assert dumped["logic"] == "AND"
    assert len(dumped["conditions"]) == 2
    assert dumped["conditions"][0]["field"] == "cgpa"
    assert dumped["conditions"][0]["value"] == 8.0


def test_branch_normalization():
    raw_branches = [
        "Computer Science",
        "it",
        "Electronics and Communication",
        "Artificial Intelligence",
        "mech",
    ]
    normalized = normalize_branch_list(raw_branches)
    assert "CSE" in normalized
    assert "IT" in normalized
    assert "ECE" in normalized
    assert "AI" in normalized
    assert "MECH" in normalized


def test_heuristic_fallback_parser():
    sample_text = (
        "We are hiring for Software Development Engineer. "
        "Eligibility: Minimum 8.0 CGPA, Computer Science and Information Technology branches only. "
        "Candidates must have 0 active backlogs and only unplaced students are eligible for this 2026 batch."
    )

    parsed = parse_job_description(sample_text)
    assert parsed["logic"] == "AND"

    fields = {c["field"]: c for c in parsed["conditions"]}
    assert "cgpa" in fields
    assert fields["cgpa"]["value"] == 8.0

    assert "branch" in fields
    assert "CSE" in fields["branch"]["value"]
    assert "IT" in fields["branch"]["value"]

    assert "backlogs" in fields
    assert fields["backlogs"]["value"] == 0

    assert "placement_status" in fields
    assert fields["placement_status"]["value"] == "unplaced"

    assert "batch" in fields
    assert fields["batch"]["value"] == 2026

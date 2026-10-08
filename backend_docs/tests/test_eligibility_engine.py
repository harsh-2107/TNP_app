"""Unit tests for Dynamic Eligibility Evaluator Engine."""

from app.services.eligibility_engine import EligibilityEngine



def test_empty_rules_is_always_eligible():
    student = {"cgpa": 6.5, "branch": "MECH"}
    res = EligibilityEngine.evaluate(student, None)
    assert res["is_eligible"] is True
    assert res["reasons"] == []

    res_empty_dict = EligibilityEngine.evaluate(student, {})
    assert res_empty_dict["is_eligible"] is True


def test_cgpa_numerical_comparison():
    student = {"cgpa": 8.2, "branch": "CSE"}

    # Passing case: >= 7.5
    rules_pass = {"field": "cgpa", "operator": ">=", "value": 7.5}
    res_pass = EligibilityEngine.evaluate(student, rules_pass)
    assert res_pass["is_eligible"] is True

    # Failing case: >= 8.5
    rules_fail = {"field": "cgpa", "operator": ">=", "value": 8.5}
    res_fail = EligibilityEngine.evaluate(student, rules_fail)
    assert res_fail["is_eligible"] is False
    assert len(res_fail["reasons"]) == 1
    assert "cgpa" in res_fail["reasons"][0].lower()


def test_branch_membership_in():
    student = {"cgpa": 8.0, "branch": "CSE"}

    rules_in = {"field": "branch", "operator": "IN", "value": ["CSE", "IT", "AIDS"]}
    res = EligibilityEngine.evaluate(student, rules_in)
    assert res["is_eligible"] is True

    # Case insensitivity test
    student_lower = {"cgpa": 8.0, "branch": "cse"}
    res_lower = EligibilityEngine.evaluate(student_lower, rules_in)
    assert res_lower["is_eligible"] is True

    # Failing branch test
    student_mech = {"cgpa": 8.0, "branch": "MECH"}
    res_mech = EligibilityEngine.evaluate(student_mech, rules_in)
    assert res_mech["is_eligible"] is False
    assert "MECH" in res_mech["reasons"][0]


def test_logical_and_group():
    rules = {
        "logic": "AND",
        "conditions": [
            {"field": "cgpa", "operator": ">=", "value": 7.0},
            {"field": "branch", "operator": "IN", "value": ["CSE", "IT"]},
            {"field": "placement_status", "operator": "==", "value": "unplaced"},
            {"field": "backlogs", "operator": "<=", "value": 0},
        ],
    }

    # Fully eligible student
    student_pass = {
        "cgpa": 7.8,
        "branch": "IT",
        "placement_status": "unplaced",
        "backlogs": 0,
    }
    assert EligibilityEngine.evaluate(student_pass, rules)["is_eligible"] is True

    # Ineligible student (multiple failed criteria)
    student_fail = {
        "cgpa": 6.8,  # fails
        "branch": "CIVIL",  # fails
        "placement_status": "placed",  # fails
        "backlogs": 1,  # fails
    }
    res = EligibilityEngine.evaluate(student_fail, rules)
    assert res["is_eligible"] is False
    assert len(res["reasons"]) == 4


def test_logical_or_group():
    rules = {
        "logic": "OR",
        "conditions": [
            {"field": "cgpa", "operator": ">=", "value": 9.0},
            {"field": "branch", "operator": "==", "value": "CSE"},
        ],
    }

    # Passes because branch is CSE (even though CGPA < 9.0)
    student = {"cgpa": 7.5, "branch": "CSE"}
    assert EligibilityEngine.evaluate(student, rules)["is_eligible"] is True

    # Fails both
    student_fail = {"cgpa": 8.5, "branch": "MECH"}
    res = EligibilityEngine.evaluate(student_fail, rules)
    assert res["is_eligible"] is False
    assert "OR" in res["reasons"][0]


def test_missing_profile_field():
    student = {"cgpa": 8.0}
    rules = {"field": "tenth_percentage", "operator": ">=", "value": 75.0}

    res = EligibilityEngine.evaluate(student, rules)
    assert res["is_eligible"] is False
    assert "Missing required profile field: 'tenth_percentage'" in res["reasons"][0]

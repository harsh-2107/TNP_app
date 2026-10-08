#Dynamic rakha hai, can be edited
# JSONB mein eligibility criteria jismein admin can edit

from typing import Any, Dict, List, Optional, Tuple, Union


class EligibilityEngine:
    """Utility engine to dynamically evaluate placement drive eligibility rules against student profiles."""

    # little less mehnat
    OPERATOR_MAP = {
        ">=": "gte",
        "gte": "gte",
        ">": "gt",
        "gt": "gt",
        "<=": "lte",
        "lte": "lte",
        "<": "lt",
        "lt": "lt",
        "==": "eq",
        "=": "eq",
        "eq": "eq",
        "!=": "ne",
        "<>": "ne",
        "ne": "ne",
        "neq": "ne",
        "in": "in",
        "IN": "in",
        "not in": "not_in",
        "NOT IN": "not_in",
        "not_in": "not_in",
        "contains": "contains",
        "icontains": "icontains",
        "startswith": "startswith",
        "endswith": "endswith",
        "exists": "exists",
        "is_null": "is_null",
        "is_not_null": "is_not_null",
    }

    @classmethod
    def evaluate(
        cls,
        student_profile: Dict[str, Any],
        eligibility_rules: Optional[Union[Dict[str, Any], List[Dict[str, Any]]]] = None,
    ) -> Dict[str, Any]:
        #Evaluate karo on the basis of criteria

        #Returns boolean ya fir if fails any then returns the failed criteria
        
        if not eligibility_rules:
            # If no rules are defined for the drive, all students are eligible
            return {"is_eligible": True, "reasons": []}

        # Normalize normalized profile
        normalized_profile = cls._normalize_profile_keys(student_profile)

        is_eligible, reasons = cls._evaluate_node(normalized_profile, eligibility_rules)

        return {
            "is_eligible": is_eligible,
            "reasons": reasons,
        }

    @classmethod
    def _normalize_profile_keys(cls, profile: Dict[str, Any]) -> Dict[str, Any]:
    #    lower case karo sab taki match ho jaye acche se
        if not isinstance(profile, dict):
            return {}
        return {str(k).lower().strip(): v for k, v in profile.items()}

    @classmethod
    def _evaluate_node(
        cls, profile: Dict[str, Any], node: Union[Dict[str, Any], List[Any]]
    ) -> Tuple[bool, List[str]]:
        #node list of conditions hain?
        if isinstance(node, list):
            all_passed = True
            collected_reasons: List[str] = []
            for item in node:
                passed, reasons = cls._evaluate_node(profile, item)
                if not passed:
                    all_passed = False
                    collected_reasons.extend(reasons)
            return all_passed, collected_reasons

        if not isinstance(node, dict):
            return True, []

        #Node group hai?
        if "logic" in node or "conditions" in node:
            logic = str(node.get("logic", "AND")).upper().strip()
            conditions = node.get("conditions", [])
            if not isinstance(conditions, list):
                conditions = [conditions]

            if not conditions:
                return True, []

            if logic == "OR":
                # OR logic: passes if ANY child condition passes
                child_results: List[Tuple[bool, List[str]]] = []
                for cond in conditions:
                    res = cls._evaluate_node(profile, cond)
                    if res[0]:
                        return True, []
                    child_results.append(res)

                # If all failed in OR, summarize failure
                all_failed_reasons = []
                for _, reasons in child_results:
                    all_failed_reasons.extend(reasons)
                
                summary_reason = (
                    f"Did not meet any of the alternative criteria (OR): "
                    + "; ".join(all_failed_reasons)
                )
                return False, [summary_reason]

            elif logic == "NOT":
               
                if len(conditions) == 1:
                    passed, reasons = cls._evaluate_node(profile, conditions[0])
                    if passed:
                        return False, ["Condition met but was negated (NOT rule)"]
                    return True, []
                return True, []

            else:
                # Default logic is AND
                all_passed = True
                collected_reasons = []
                for cond in conditions:
                    passed, reasons = cls._evaluate_node(profile, cond)
                    if not passed:
                        all_passed = False
                        collected_reasons.extend(reasons)
                return all_passed, collected_reasons

        #leaf condition
        if "field" in node:
            return cls._evaluate_condition(profile, node)

        return True, []

    @classmethod
    def _evaluate_condition(
        cls, profile: Dict[str, Any], condition: Dict[str, Any]
    ) -> Tuple[bool, List[str]]:
        """Evaluate an individual leaf condition against the student profile."""
        field = str(condition.get("field", "")).lower().strip()
        raw_op = str(condition.get("operator", "==")).strip()
        expected_val = condition.get("value")

        if not field:
            return True, []

        op_key = cls.OPERATOR_MAP.get(raw_op, raw_op.lower())

        # Check existence in profile
        if field not in profile: #Agar profile me nahi hua to check karo possibles ke liye
            # Check for standard aliases
            aliases = {
                "cgpa": ["gpa", "pointer", "grade_point"],
                "branch": ["department", "dept", "course", "degree_branch"],
                "placement_status": ["status", "placed_status", "is_placed"],
                "backlogs": ["active_backlogs", "arrears", "standing_backlogs", "backlog_count"],
                "batch": ["graduation_year", "passing_year", "passout_year"],
                "tenth_percentage": ["10th_percentage", "tenth_pct", "10th_marks", "ssc_percentage"],
                "twelfth_percentage": ["12th_percentage", "twelfth_pct", "12th_marks", "hsc_percentage"],
            }
            matched_alias = None
            for alias in aliases.get(field, []):
                if alias in profile:
                    matched_alias = alias
                    break

            if matched_alias:
                actual_val = profile[matched_alias]
            else:
                if op_key in ("is_null", "not_exists"):
                    return True, []
                return False, [f"Missing required profile field: '{field}'"]
        else:
            actual_val = profile[field]

        # Evaluate based on operator
        passed, reason = cls._compare(field, actual_val, op_key, raw_op, expected_val)
        if not passed:
            return False, [reason]
        return True, []

    @classmethod
    def _compare(
        cls,
        field_name: str,
        actual: Any,
        op_key: str,
        display_op: str,
        expected: Any,
    ) -> Tuple[bool, str]:
        """Perform typed comparison between actual student profile value and expected criterion value."""
        if op_key == "is_null":
            passed = actual is None
            return passed, "" if passed else f"Field '{field_name}' must be null"

        if op_key == "is_not_null":
            passed = actual is not None
            return passed, "" if passed else f"Field '{field_name}' cannot be null"

        if op_key == "exists":
            return True, ""

        # If actual value is None at this point, fail comparison
        if actual is None:
            return False, f"Field '{field_name}' is null in student profile"

        # 2. Membership / IN operators
        if op_key in ("in", "not_in"):
            # Expected should be a list/set/tuple
            expected_list = expected if isinstance(expected, (list, set, tuple)) else [expected]

            # Case-insensitive string matching
            if isinstance(actual, str):
                normalized_actual = actual.strip().lower()
                normalized_expected = [
                    str(x).strip().lower() if isinstance(x, str) else x for x in expected_list
                ]
                is_in = normalized_actual in normalized_expected
            elif isinstance(actual, (list, set, tuple)):
                # Student has a list (e.g. skills) 
                actual_set = {str(x).strip().lower() for x in actual}
                expected_set = {str(x).strip().lower() for x in expected_list}
                is_in = bool(actual_set.intersection(expected_set))
            else:
                is_in = actual in expected_list

            if op_key == "in":
                if not is_in:
                    return (
                        False,
                        f"Field '{field_name}' with value '{actual}' is not in allowed list: {expected_list}",
                    )
                return True, ""
            else:  # not_in
                if is_in:
                    return (
                        False,
                        f"Field '{field_name}' with value '{actual}' is in disallowed list: {expected_list}",
                    )
                return True, ""

        # 3. substring operators
        if op_key in ("contains", "icontains", "startswith", "endswith"):
            actual_str = str(actual)
            expected_str = str(expected)

            if op_key == "icontains":
                passed = expected_str.lower() in actual_str.lower()
            elif op_key == "contains":
                passed = expected_str in actual_str
            elif op_key == "startswith":
                passed = actual_str.lower().startswith(expected_str.lower())
            elif op_key == "endswith":
                passed = actual_str.lower().endswith(expected_str.lower())
            else:
                passed = False

            if not passed:
                return (
                    False,
                    f"Field '{field_name}' ('{actual}') does not satisfy {display_op} '{expected}'",
                )
            return True, ""

       #numerics
        if op_key in ("gte", "gt", "lte", "lt"):
            try:
                actual_num = float(actual)
                expected_num = float(expected)
            except (ValueError, TypeError):
                return (
                    False,
                    f"Non-numeric comparison for field '{field_name}': actual='{actual}', expected='{expected}'",
                )

            passed = False
            if op_key == "gte":
                passed = actual_num >= expected_num
            elif op_key == "gt":
                passed = actual_num > expected_num
            elif op_key == "lte":
                passed = actual_num <= expected_num
            elif op_key == "lt":
                passed = actual_num < expected_num

            if not passed:
                return (
                    False,
                    f"Field '{field_name}' requirement failed: required {display_op} {expected}, student has {actual}",
                )
            return True, ""

        #eq and ne
        if op_key in ("eq", "ne"):
            is_equal = False
            try:
                if (isinstance(actual, (int, float)) or (isinstance(actual, str) and actual.replace(".", "", 1).isdigit())) and \
                   (isinstance(expected, (int, float)) or (isinstance(expected, str) and expected.replace(".", "", 1).isdigit())):
                    is_equal = float(actual) == float(expected)
                elif isinstance(actual, str) and isinstance(expected, str):
                    # Case-insensitive equality for strings
                    is_equal = actual.strip().lower() == expected.strip().lower()
                elif isinstance(actual, bool) or isinstance(expected, bool):
                    is_equal = bool(actual) == bool(expected)
                else:
                    is_equal = actual == expected
            except Exception:
                is_equal = actual == expected

            if op_key == "eq":
                if not is_equal:
                    return (
                        False,
                        f"Field '{field_name}' requirement failed: required {display_op} '{expected}', student has '{actual}'",
                    )
                return True, ""
            else:  # ne
                if is_equal:
                    return (
                        False,
                        f"Field '{field_name}' requirement failed: cannot be equal to '{expected}'",
                    )
                return True, ""

        return True, ""

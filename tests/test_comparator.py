"""Unit tests for comparator normalization behavior."""

from __future__ import annotations

import unittest

from altitest.comparator import strict_compare


class ComparatorNormalizationTests(unittest.TestCase):
    def test_ignores_banner_and_connection_port(self) -> None:
        expected = """
-----------------------------------------------------------------
     Altibase Client Query utility.
     Release Version 7.1.0.2.4
     Copyright 2000, ALTIBASE Corporation or its subsidiaries.
     All Rights Reserved.
-----------------------------------------------------------------
ISQL_CONNECTION = TCP, SERVER = localhost, PORT_NO = 17730
iSQL> select 1 from dual;
1
1 row selected.
"""
        actual = """
-----------------------------------------------------------------
     Altibase Client Query utility.
     Release Version 7.3.0.0.0
     Copyright 2000, ALTIBASE Corporation or its subsidiaries.
     All Rights Reserved.
-----------------------------------------------------------------
ISQL_CONNECTION = TCP, SERVER = localhost, PORT_NO = 20300
iSQL> select 1 from dual;
1
1 row selected.
"""
        same, _, _ = strict_compare(expected, actual, raw_diff=False)
        self.assertTrue(same)

    def test_ignores_query_time_line(self) -> None:
        expected = """
iSQL> set timing on;
iSQL> select 1 from dual;
1
Query Time : 44.62 msec
1 row selected.
"""
        actual = """
iSQL> set timing on;
iSQL> select 1 from dual;
1
Query Time : 1.23 msec
1 row selected.
"""
        same, _, _ = strict_compare(expected, actual, raw_diff=False)
        self.assertTrue(same)

    def test_raw_diff_keeps_query_time_difference(self) -> None:
        expected = "Query Time : 44.62 msec\n"
        actual = "Query Time : 1.23 msec\n"
        same, _, _ = strict_compare(expected, actual, raw_diff=True)
        self.assertFalse(same)


if __name__ == "__main__":
    unittest.main()

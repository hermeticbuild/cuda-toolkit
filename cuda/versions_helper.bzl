# Copyright 2015 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Macros for building CUDA code.

def _compare_versions(lib_version, dist_version, operator):
    """Helper function to compare two version strings."""
    if not lib_version:
        return False
    lib_tuple = tuple([int(x) for x in lib_version.split(".")])
    dist_tuple = tuple([int(x) for x in dist_version.split(".")])
    
    if operator == "<=":
        return lib_tuple <= dist_tuple
    elif operator == ">=":
        return lib_tuple >= dist_tuple
    elif operator == ">":
        return lib_tuple > dist_tuple
    elif operator == "<":
        return lib_tuple < dist_tuple
    return False

def if_version_equal_or_lower_than(lib_version, dist_version, if_true, if_false = []):
    if _compare_versions(lib_version, dist_version, "<="):
        return if_true
    return if_false

def if_version_equal_or_greater_than(lib_version, dist_version, if_true, if_false = []):
    if _compare_versions(lib_version, dist_version, ">="):
        return if_true
    return if_false

def if_version_greater_than(lib_version, dist_version, if_true, if_false = []):
    if _compare_versions(lib_version, dist_version, ">"):
        return if_true
    return if_false

def if_version_lower_than(lib_version, dist_version, if_true, if_false = []):
    if _compare_versions(lib_version, dist_version, "<"):
        return if_true
    return if_false

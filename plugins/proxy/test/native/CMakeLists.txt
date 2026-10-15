cmake_minimum_required(VERSION 3.14)
project(proxy_ownership_tests LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(FetchContent)
FetchContent_Declare(googletest
  GIT_REPOSITORY https://github.com/google/googletest.git
  GIT_TAG 52eb8108c5bdec04579160ae17225d66034bd723
)
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(googletest)

enable_testing()
add_executable(proxy_ownership_tests ../../windows/test/proxy_ownership_test.cpp)
target_include_directories(proxy_ownership_tests PRIVATE ../../windows)
target_link_libraries(proxy_ownership_tests PRIVATE gtest_main)
include(GoogleTest)
gtest_discover_tests(proxy_ownership_tests)

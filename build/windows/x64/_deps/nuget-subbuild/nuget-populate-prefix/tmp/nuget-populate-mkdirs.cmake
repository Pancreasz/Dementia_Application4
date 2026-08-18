# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file LICENSE.rst or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION ${CMAKE_VERSION}) # this file comes with cmake

# If CMAKE_DISABLE_SOURCE_CHANGES is set to true and the source directory is an
# existing directory in our source tree, calling file(MAKE_DIRECTORY) on it
# would cause a fatal error, even though it would be a no-op.
if(NOT EXISTS "D:/moca_ad/Dementia_Application4/build/windows/x64/_deps/nuget-src")
  file(MAKE_DIRECTORY "D:/moca_ad/Dementia_Application4/build/windows/x64/_deps/nuget-src")
endif()
file(MAKE_DIRECTORY
  "D:/moca_ad/Dementia_Application4/build/windows/x64/_deps/nuget-build"
  "D:/moca_ad/Dementia_Application4/build/windows/x64/_deps/nuget-subbuild/nuget-populate-prefix"
  "D:/moca_ad/Dementia_Application4/build/windows/x64/_deps/nuget-subbuild/nuget-populate-prefix/tmp"
  "D:/moca_ad/Dementia_Application4/build/windows/x64/_deps/nuget-subbuild/nuget-populate-prefix/src/nuget-populate-stamp"
  "D:/moca_ad/Dementia_Application4/build/windows/x64/_deps/nuget-subbuild/nuget-populate-prefix/src"
  "D:/moca_ad/Dementia_Application4/build/windows/x64/_deps/nuget-subbuild/nuget-populate-prefix/src/nuget-populate-stamp"
)

set(configSubDirs Debug)
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "D:/moca_ad/Dementia_Application4/build/windows/x64/_deps/nuget-subbuild/nuget-populate-prefix/src/nuget-populate-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "D:/moca_ad/Dementia_Application4/build/windows/x64/_deps/nuget-subbuild/nuget-populate-prefix/src/nuget-populate-stamp${cfgdir}") # cfgdir has leading slash
endif()

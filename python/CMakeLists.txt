find_package(Python REQUIRED COMPONENTS Interpreter Development.Module NumPy)
find_package(Cython MODULE REQUIRED VERSION 3.0)
include(UseCython)

# Include intelligent cross-platform wheel dependency bundling
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../cmake")
include(WheelDependencyBundling)

cython_transpile(imas_core/_al_lowlevel.pyx LANGUAGE CXX OUTPUT_VARIABLE _al_lowlevel_source)
cython_transpile(imas_core/al_defs.pyx LANGUAGE CXX OUTPUT_VARIABLE al_defs_source)
python_add_library(_al_lowlevel MODULE ${_al_lowlevel_source} WITH_SOABI)
python_add_library(al_defs MODULE ${al_defs_source} WITH_SOABI)
target_link_libraries(_al_lowlevel PRIVATE Python::NumPy al)
target_link_libraries(al_defs PRIVATE Python::NumPy al)
set_target_properties(al PROPERTIES INSTALL_RPATH $ORIGIN)
set_target_properties(_al_lowlevel al_defs PROPERTIES INSTALL_RPATH $ORIGIN/../imas_core.libs)
install(FILES $<TARGET_RUNTIME_DLLS:al> DESTINATION imas_core.libs)
install(FILES $<TARGET_RUNTIME_DLLS:_al_lowlevel> DESTINATION imas_core.libs)
install(FILES $<TARGET_RUNTIME_DLLS:al_defs> DESTINATION imas_core.libs)

# Configure intelligent cross-platform bundling of runtime dependencies
setup_wheel_dependency_bundling()
print_wheel_bundling_config()

# Install with platform-intelligent runtime dependency bundling
install_with_bundled_dependencies(
  TARGETS al
  DESTINATION imas_core.libs
)

install(TARGETS _al_lowlevel al_defs DESTINATION imas_core)

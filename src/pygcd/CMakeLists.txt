add_custom_command(
    OUTPUT _core.c
    COMMAND Python::Interpreter -m cython
          "${CMAKE_CURRENT_SOURCE_DIR}/_core.pyx" --output-file _core.c
    DEPENDS _core.pyx
)

python_add_library(_core MODULE _core.c WITH_SOABI)

set_target_properties(_core PROPERTIES OUTPUT_NAME "_core")

# Link against the dispatch framework (GCD) on macOS
if(APPLE)
    target_link_libraries(_core PRIVATE "-framework CoreFoundation")
endif()

install(TARGETS _core DESTINATION pygcd)

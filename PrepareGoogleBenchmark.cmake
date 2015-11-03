INCLUDE(ExternalProject)

FUNCTION(DOWNLOAD_GOOGLE_BENCHMARK)
    SET_DIRECTORY_PROPERTIES(properties EP_PREFIX "${CMAKE_BINARY_DIR}/foreign")
    ExternalProject_Add(google-benchmark
        URL https://s3-us-west-2.amazonaws.com/blackhole.testing/google-benchmark.tar.gz
        SOURCE_DIR ${CMAKE_BINARY_DIR}/foreign/google-benchmark
        CMAKE_ARGS -DCMAKE_BUILD_TYPE=Release
        INSTALL_COMMAND ""
    )

    ExternalProject_GET_PROPERTY(google-benchmark SOURCE_DIR)
    ExternalProject_GET_PROPERTY(google-benchmark BINARY_DIR)

    SET(GOOGLE_BENCHMARK_INCLUDE_DIR ${SOURCE_DIR}/include PARENT_SCOPE)
    SET(GOOGLE_BENCHMARK_BINARY_DIR ${BINARY_DIR}/src PARENT_SCOPE)
ENDFUNCTION()

function(prepare_google_benchmarking)
    download_google_benchmark()

    include_directories(SYSTEM PARENT_SCOPE
        ${GOOGLE_BENCHMARK_INCLUDE_DIR}
    )

    link_directories(${GOOGLE_BENCHMARK_BINARY_DIR})
endfunction()

function(enable_google_benchmarking __TARGET__)
    add_dependencies(${__TARGET__} google-benchmark)
endfunction()

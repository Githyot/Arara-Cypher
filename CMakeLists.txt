# AraraCypher: o app é escrito em Rust (crate app/) com interface em QML.
# O CMake só junta tudo num executável Qt, porque é o caminho que o Qt usa
# para gerar o APK do Android. No Fedora, o mesmo CMakeLists gera o binário.
cmake_minimum_required(VERSION 3.24)

project(AraraCypher VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Multimedia)
# Ferramenta só do desktop; no Android o androiddeployqt faz essa varredura.
find_package(Qt6 6.4 QUIET OPTIONAL_COMPONENTS QmlImportScanner)

# Com o Android NDK, o Rust precisa compilar para o mesmo processador do APK.
if(ANDROID)
    if(ANDROID_ABI STREQUAL "arm64-v8a")
        set(Rust_CARGO_TARGET "aarch64-linux-android")
    elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
        set(Rust_CARGO_TARGET "armv7-linux-androideabi")
    elseif(ANDROID_ABI STREQUAL "x86_64")
        set(Rust_CARGO_TARGET "x86_64-linux-android")
    elseif(ANDROID_ABI STREQUAL "x86")
        set(Rust_CARGO_TARGET "i686-linux-android")
    endif()
endif()

find_package(CxxQt QUIET)
if(NOT CxxQt_FOUND)
    include(FetchContent)
    FetchContent_Declare(
        CxxQt
        GIT_REPOSITORY https://github.com/kdab/cxx-qt-cmake.git
        GIT_TAG 64e63f560737b3b7f85ef8267c5918e4b8176d5a # 0.10.0
    )
    FetchContent_MakeAvailable(CxxQt)
endif()

# No Android, o qmake do Qt para Android (um script que aponta para os headers
# do alvo) precisa ser usado; o padrão pegaria o qmake do host e os headers errados.
set(ARARA_QMAKE_ARG "")
if(ANDROID)
    set(ARARA_QMAKE_ARG QMAKE "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_BINS}/qmake")
endif()

cxx_qt_import_crate(
    MANIFEST_PATH app/Cargo.toml
    CRATES araracypher_app
    LOCKED
    ${ARARA_QMAKE_ARG}
    QT_MODULES Qt::Core Qt::Gui Qt::Qml Qt::Quick Qt::QuickControls2
)

cxx_qt_import_qml_module(araracypher_qml_module
    URI "AraraCypher"
    SOURCE_CRATE araracypher_app)

qt_add_executable(araracypher cpp/main.cpp cpp/mic.cpp cpp/mic.h)
target_link_libraries(araracypher PRIVATE araracypher_qml_module Qt::Quick Qt::QuickControls2 Qt::Multimedia)
if(TARGET Qt6::qmlimportscanner OR Qt6QmlImportScanner_FOUND)
    qt_import_qml_plugins(araracypher)
endif()
# Onde o androiddeployqt procura os imports QML para empacotar no APK.
set_property(TARGET araracypher APPEND PROPERTY
    QT_QML_ROOT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/app/qml")

set_target_properties(araracypher PROPERTIES
    QT_ANDROID_PACKAGE_NAME "io.github.githyot.araracypher"
    QT_ANDROID_APP_NAME "AraraCypher"
    QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"
    QT_ANDROID_VERSION_CODE 1
)

if(NOT ANDROID)
    include(GNUInstallDirs)
    install(TARGETS araracypher RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    install(FILES packaging/io.github.githyot.araracypher.desktop
            DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
    install(FILES packaging/io.github.githyot.araracypher.svg
            DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)

    # Pacote .rpm para o Fedora: `cpack -G RPM` dentro da pasta de build.
    set(CPACK_PACKAGE_NAME "araracypher")
    set(CPACK_PACKAGE_VENDOR "Githyot")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Escreva cifras e tablaturas de violão e guitarra")
    set(CPACK_PACKAGE_CONTACT "Githyot")
    set(CPACK_RPM_PACKAGE_LICENSE "GPL-3.0-or-later")
    set(CPACK_RPM_PACKAGE_GROUP "Applications/Multimedia")
    set(CPACK_RPM_PACKAGE_URL "https://github.com/Githyot/Arara-Cypher")
    set(CPACK_RPM_PACKAGE_REQUIRES "qt6-qtbase, qt6-qtdeclarative, qt6-qtmultimedia, tesseract, tesseract-langpack-por")
    set(CPACK_RPM_PACKAGE_AUTOREQ ON)
    set(CPACK_RPM_FILE_NAME RPM-DEFAULT)
    # Release sobe a cada build do CI (número da execução), para o
    # "dnf upgrade" reconhecer o pacote novo sem desinstalar o antigo.
    set(ARARA_RELEASE "1" CACHE STRING "Release do pacote .rpm")
    set(CPACK_RPM_PACKAGE_RELEASE "${ARARA_RELEASE}")
    set(CPACK_RPM_PACKAGE_RELEASE_DIST ON)
    set(CPACK_PACKAGING_INSTALL_PREFIX "/usr")
    include(CPack)
endif()

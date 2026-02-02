#!/bin/bash

mkdir -p win_deps && cd win_deps

mkdir -p include

wget https://github.com/libsdl-org/SDL/releases/download/release-3.4.0/SDL3-3.4.0.zip
unzip SDL3-3.4.0.zip
rm SDL3-3.4.0.zip
cp -r SDL3-3.4.0/include/SDL3 include/
rm -rf SDL3-3.4.0

wget https://github.com/libsdl-org/SDL_ttf/releases/download/release-3.2.2/SDL3_ttf-3.2.2.zip
unzip SDL3_ttf-3.2.2.zip
rm SDL3_ttf-3.2.2.zip
cp -r SDL3_ttf-3.2.2/include/SDL3_ttf include/
rm -rf SDL3_ttf-3.2.2

wget https://github.com/libsdl-org/SDL_image/releases/download/release-3.4.0/SDL3_image-3.4.0.zip
unzip SDL3_image-3.4.0.zip
rm SDL3_image-3.4.0.zip
cp -r SDL3_image-3.4.0/include/SDL3_image include/
rm -rf SDL3_image-3.4.0

mkdir -p x86_64 && cd x86_64

wget https://github.com/libsdl-org/SDL/releases/download/release-3.4.0/SDL3-3.4.0-win32-x64.zip
unzip SDL3-3.4.0-win32-x64.zip -d SDL3-3.4.0-win32-x64
rm SDL3-3.4.0-win32-x64.zip
cp SDL3-3.4.0-win32-x64/SDL3.dll ./
rm -rf SDL3-3.4.0-win32-x64

wget https://github.com/libsdl-org/SDL_ttf/releases/download/release-3.2.2/SDL3_ttf-3.2.2-win32-x64.zip
unzip SDL3_ttf-3.2.2-win32-x64.zip -d SDL3_ttf-3.2.2-win32-x64
rm SDL3_ttf-3.2.2-win32-x64.zip
cp SDL3_ttf-3.2.2-win32-x64/SDL3_ttf.dll ./
rm -rf SDL3_ttf-3.2.2-win32-x64

wget https://github.com/libsdl-org/SDL_image/releases/download/release-3.4.0/SDL3_image-3.4.0-win32-x64.zip
unzip SDL3_image-3.4.0-win32-x64.zip -d SDL3_image-3.4.0-win32-x64
rm SDL3_image-3.4.0-win32-x64.zip
cp SDL3_image-3.4.0-win32-x64/SDL3_image.dll ./
rm -rf SDL3_image-3.4.0-win32-x64
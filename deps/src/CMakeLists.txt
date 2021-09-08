cmake_minimum_required(VERSION 3.14)
project(Mercury VERSION 0.1 LANGUAGES C)

add_library(hg SHARED
    mercury.h
    mercury.c
)
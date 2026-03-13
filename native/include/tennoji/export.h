#ifndef TENNOJI_EXPORT_H
#define TENNOJI_EXPORT_H

#ifdef _WIN32
  #ifdef TENNOJI_BUILD
    #define TENNOJI_EXPORT __declspec(dllexport)
  #else
    #define TENNOJI_EXPORT __declspec(dllimport)
  #endif
#else
  #define TENNOJI_EXPORT __attribute__((visibility("default")))
#endif

#endif // TENNOJI_EXPORT_H

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

#ifdef __cplusplus
#define __EXTERN_C__ extern "C" {
#define __UNEXTERN_C__ }
#else 
#define __EXTERN_C__
#define __UNEXTERN_C__
#endif

#endif // TENNOJI_EXPORT_H

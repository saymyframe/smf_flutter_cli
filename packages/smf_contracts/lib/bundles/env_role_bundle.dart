// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, implicit_dynamic_list_literal, implicit_dynamic_map_literal, inference_failure_on_collection_literal

import 'package:mason/mason.dart';

final envRoleBundle = MasonBundle.fromJson(<String, dynamic>{
  "files": [
    {
      "path": ".env",
      "data":
          "IyBUaGUgdmFsdWVzIHRoYXQgdGhlIGFwcCByZWFkcywgZWFjaCB1bmRlciBhIGNvbW1lbnQgdGhhdCBzYXlzIHdoYXQgZ29lcwojIHRoZXJlLiBUaGlzIGZpbGUgc3RheXMgb3V0IG9mIGdpdDsgLmVudi5leGFtcGxlIGhhcyB0aGUgc2FtZSBrZXlzIHdpdGhvdXQKIyB2YWx1ZXMuIEV2ZXJ5IHZhbHVlIGVuZHMgdXAgaW4gdGhlIGFwcCwgd2hlcmUgYW55b25lIGNhbiByZWFkIGl0LCBzbyBuZXZlcgojIHB1dCBhIHNlY3JldCBoZXJlLiBBbiBlbXB0eSB2YWx1ZSBjb3VudHMgYXMgbWlzc2luZy4KIwojIFdyaXRlIGEgdmFsdWUgYXMgaXQgaXMsIG9yIGluIGRvdWJsZSBxdW90ZXMgaWYgaXQgaGFzIGEgc3BhY2UsIGEgIyBvciBhIHF1b3RlLgp7e3tlbnZfa2V5c319fQo=",
      "type": "text"
    },
    {
      "path": ".env.example",
      "data":
          "IyBUaGlzIGZpbGUgbGlzdHMgdGhlIGtleXMgb2YgdGhlIHZhbHVlcyB0aGF0IHRoZSBhcHAgcmVhZHMsIGVhY2ggdW5kZXIgYQojIGNvbW1lbnQgdGhhdCBzYXlzIHdoYXQgZ29lcyB0aGVyZS4gQWZ0ZXIgYSBjbG9uZSwgY29weSBpdCB0byAuZW52IGFuZCBmaWxsCiMgaW4gdGhlIHZhbHVlcyB0aGVyZTsgLmVudiBzdGF5cyBvdXQgb2YgZ2l0LiBFdmVyeSB2YWx1ZSBlbmRzIHVwIGluIHRoZSBhcHAsCiMgd2hlcmUgYW55b25lIGNhbiByZWFkIGl0LCBzbyBuZXZlciBwdXQgYSBzZWNyZXQgaW50byBvbmUuIEFuIGVtcHR5IHZhbHVlCiMgY291bnRzIGFzIG1pc3NpbmcuCiMKIyBXcml0ZSBhIHZhbHVlIGFzIGl0IGlzLCBvciBpbiBkb3VibGUgcXVvdGVzIGlmIGl0IGhhcyBhIHNwYWNlLCBhICMgb3IgYSBxdW90ZS4Ke3t7ZW52X2tleXN9fX0K",
      "type": "text"
    },
    {
      "path": "lib/core/env/env_check.dart",
      "data":
          "Ly8gVGhlIGNoZWNrIHRoYXQgYSBidWlsZCBvZiB0aGUgYXBwIGhhcyB0aGUgdmFsdWVzIG9mIC5lbnYsIHdoaWNoIGJvb3RzdHJhcCgpCi8vIGNhbGxzIGluIGl0cyBmaXJzdCBwaGFzZS4gSXQgaXMgcGxhaW4gRGFydCwgc28gdGhhdCBhIHRlc3QgY29tcGlsZXMgaXQgd2l0aAovLyB0aGUgRGFydCBTREsgYWxvbmUuCmltcG9ydCAnYXBwX2Vudi5kYXJ0JzsKCi8vLyBXaGV0aGVyIHRoaXMgaXMgYSByZWxlYXNlIGJ1aWxkLCB3aGljaCB0aGUgY29tcGlsZXIgb2YgYSByZWxlYXNlIGJ1aWxkCi8vLyBkZWNsYXJlcy4KY29uc3QgX3JlbGVhc2UgPSBib29sLmZyb21FbnZpcm9ubWVudCgnZGFydC52bS5wcm9kdWN0Jyk7CgovLy8gV2hldGhlciB0aGUgY29tbWFuZCB0aGF0IGJ1aWx0IHRoZSBhcHAgZ2F2ZSBpdCB0aGUgdmFsdWVzIG9mIGAuZW52YCwgYXMKLy8vIFtBcHBFbnYuc3VwcGxpZWRdIHNheXMuIEEgcmVsZWFzZSBidWlsZCB3aXRob3V0IHRoZW0gY2Fubm90IGV2YWx1YXRlCi8vLyB0aGlzIGNvbnN0YW50LCBzbyBpdCBzdG9wcyBoZXJlLCBhbmQgdGhlIGNvbXBpbGVyIHF1b3RlcyB0aGUgdGV4dC4KY29uc3QgYm9vbCBfc3VwcGxpZWQgPSBBcHBFbnYuc3VwcGxpZWQgfHwgIV9yZWxlYXNlCiAgICA/IEFwcEVudi5zdXBwbGllZAogICAgOiAoe3t7ZW52X3JlbGVhc2VfZXJyb3J9fX0KICAgICAgICAgIGFzIGJvb2wpOwoKLy8vIFRlbGxzIGEgZGVidWcgb3IgcHJvZmlsZSBidWlsZCB0aGF0IGhhcyBub25lIG9mIHRoZSB2YWx1ZXMgb2YgYC5lbnZgLAovLy8gdGhyb3VnaCBbcmVwb3J0XSwgdGhhdCBldmVyeSBnZXR0ZXIgb2YgW0FwcEVudl0gaXMgYG51bGxgLCBhbmQgaG93IHRvCi8vLyBnaXZlIHRoZSB2YWx1ZXM7IGBib290c3RyYXAoKWAgY2FsbHMgaXQgaW4gaXRzIGZpcnN0IHBoYXNlLCB3aXRoCi8vLyBgZGVidWdQcmludGAuCnZvaWQgY2hlY2tFbnZWYWx1ZXModm9pZCBGdW5jdGlvbihTdHJpbmcgbWVzc2FnZSkgcmVwb3J0KSB7CiAgaWYgKF9zdXBwbGllZCkgcmV0dXJuOwogIHJlcG9ydCgKICAgIHt7e2Vudl9ub192YWx1ZXNfbWVzc2FnZX19fSwKICApOwp9Cg==",
      "type": "text"
    }
  ],
  "hooks": [],
  "name": "env_role",
  "description":
      "The template of the env role of SMF: .env, with the values that the modules of the app read, .env.example, with their keys, and the check that stops a release build without the values.",
  "version": "0.1.0+1",
  "environment": {"mason": "^0.1.1"},
  "vars": {}
});

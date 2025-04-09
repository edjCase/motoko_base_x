import { test } "mo:test";
import Debug "mo:base/Debug";
import Runtime "mo:new-base/Runtime";
import Blob "mo:new-base/Blob";
import Base64 "../src";

test(
  "to/fromBase64",
  func() {
    let testCases : [{ input : Blob; isUriSafe : Bool; expected : Text }] = [
      {
        input = "\48\49\50\51\52\53\54\55\56\57";
        isUriSafe = false;
        expected = "SElQUVJTVFVWVw==";
      },
      {
        input = "\48\49\50\51\52\53\54\55\56\57";
        isUriSafe = true;
        expected = "SElQUVJTVFVWVw";
      },
      {
        input = "\48\49\50\51\52\53\54\55";
        isUriSafe = false;
        expected = "SElQUVJTVFU=";
      },
      {
        input = "\48\49\50\51\52\53\54\55";
        isUriSafe = true;
        expected = "SElQUVJTVFU";
      },
      {
        input = "\FC\03\3F";
        isUriSafe = false;
        expected = "/AM/";
      },
      {
        input = "\FC\03\3F";
        isUriSafe = true;
        expected = "_AM_";
      },
      {
        input = "\01";
        isUriSafe = false;
        expected = "AQ==";
      },
      {
        input = "\01";
        isUriSafe = true;
        expected = "AQ";
      },
      {
        input = "\01\02";
        isUriSafe = false;
        expected = "AQI=";
      },
      {
        input = "\01\02";
        isUriSafe = true;
        expected = "AQI";
      },
      {
        input = "\FB\FF\FF";
        isUriSafe = false;
        expected = "+///";
      },
      {
        input = "\FB\FF\FF";
        isUriSafe = true;
        expected = "-___";
      },
      {
        input = "\AA\55\FF";
        isUriSafe = false;
        expected = "qlX/";
      },
      {
        input = "\AA\55\FF";
        isUriSafe = true;
        expected = "qlX_";
      },
      {
        // Empty string
        input = "";
        isUriSafe = false;
        expected = "";
      },
      {
        // Single character (requires double padding)
        input = "A";
        isUriSafe = false;
        expected = "QQ==";
      },
      {
        // Single character URI-safe (no padding)
        input = "A";
        isUriSafe = true;
        expected = "QQ";
      },
      {
        // Two characters (requires single padding)
        input = "BC";
        isUriSafe = false;
        expected = "QkM=";
      },
      {
        // Two characters URI-safe (no padding)
        input = "BC";
        isUriSafe = true;
        expected = "QkM";
      },
      {
        // Three characters (no padding required)
        input = "DEF";
        isUriSafe = false;
        expected = "REVG";
      },
      {
        // Special characters
        input = "!@#$%";
        isUriSafe = false;
        expected = "IUAjJCU=";
      },
      {
        // Binary data with zeros
        input = "\00\01\02\03";
        isUriSafe = false;
        expected = "AAECAw==";
      },
      {
        // UTF-8 characters (corrected)
        input = "→★♠";
        isUriSafe = false;
        expected = "4oaS4piF4pmg";
      },
      {
        // Longer text string
        input = "Base64 encoding test 123!";
        isUriSafe = true;
        expected = "QmFzZTY0IGVuY29kaW5nIHRlc3QgMTIzIQ";
      },

      {
        // Mixed case alphanumeric with punctuation
        input = "Hello, World! 123";
        isUriSafe = false;
        expected = "SGVsbG8sIFdvcmxkISAxMjM=";
      },
      {
        // Special characters that require URI-safe encoding
        input = "~!@#$%^&*()_+{}|:<>?";
        isUriSafe = true;
        expected = "fiFAIyQlXiYqKClfK3t9fDo8Pj8";
      },
      {
        // Multi-byte UTF-8 characters
        input = "日本語";
        isUriSafe = false;
        expected = "5pel5pys6Kqe";
      },
      {
        // Mix of ASCII and UTF-8
        input = "ABC中文DEF";
        isUriSafe = true;
        expected = "QUJD5Lit5paHREVG";
      },
      {
        // Binary data with pattern
        input = "\01\02\03\04\05\06\07\08";
        isUriSafe = false;
        expected = "AQIDBAUGBwg=";
      },
      {
        // String length that produces 1 padding character
        input = "12345";
        isUriSafe = false;
        expected = "MTIzNDU=";
      },
      {
        // Repeating characters
        input = "AAAABBBBCCCC";
        isUriSafe = true;
        expected = "QUFBQUJCQkJDQ0ND";
      },
      {
        // Includes null bytes and other control characters
        input = "\00\01\10\11\20\21";
        isUriSafe = false;
        expected = "AAEQESAh";
      },
      {
        // Characters that map to different values in base64
        input = "+/=";
        isUriSafe = false;
        expected = "Ky89";
      },
      {
        // Same characters in URI-safe mode
        input = "+/=";
        isUriSafe = true;
        expected = "Ky89";
      }

    ];
    for (testCase in testCases.vals()) {
      let actual = Base64.toBase64(testCase.input.vals(), testCase.isUriSafe);
      if (actual != testCase.expected) {
        Debug.trap(
          "toBase64 Failure\nValue: " # debug_show (testCase.input) # "\nIsUriSafe: " # debug_show (testCase.isUriSafe) # "\nExpected: " # testCase.expected # "\nActual:   " # actual
        );
      };
      switch (Base64.fromBase64(actual)) {
        case (#err(e)) Runtime.trap("Failed to decode base64 value: " # actual # ". Error: " # e);
        case (#ok(actualReverse)) {
          let actualReverseBlob = Blob.fromArray(actualReverse);
          if (actualReverseBlob != testCase.input) {
            Runtime.trap("fromBase64 Failure\nValue: " # debug_show (actual) # "\nIsUriSafe: " # debug_show (testCase.isUriSafe) # "\nExpected: " # debug_show (testCase.input) # "\nActual:   " # debug_show (actualReverseBlob));
          };
        };
      };
    };
  },
);

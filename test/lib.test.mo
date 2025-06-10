import { test } "mo:test";
import Debug "mo:base/Debug";
import Runtime "mo:new-base/Runtime";
import Blob "mo:new-base/Blob";
import BaseX "../src";

test(
  "to/fromBase64",
  func() {
    let testCases : [{
      input : Blob;
      outputFormat : BaseX.Base64OutputFormat;
      expected : Text;
    }] = [
      {
        input = "\48\49\50\51\52\53\54\55\56\57";
        outputFormat = #standard;
        expected = "SElQUVJTVFVWVw==";
      },
      {
        input = "\48\49\50\51\52\53\54\55\56\57";
        outputFormat = #url;
        expected = "SElQUVJTVFVWVw";
      },
      {
        input = "\48\49\50\51\52\53\54\55";
        outputFormat = #standard;
        expected = "SElQUVJTVFU=";
      },
      {
        input = "\48\49\50\51\52\53\54\55";
        outputFormat = #url;
        expected = "SElQUVJTVFU";
      },
      {
        input = "\FC\03\3F";
        outputFormat = #standard;
        expected = "/AM/";
      },
      {
        input = "\FC\03\3F";
        outputFormat = #url;
        expected = "_AM_";
      },
      {
        input = "\01";
        outputFormat = #standard;
        expected = "AQ==";
      },
      {
        input = "\01";
        outputFormat = #url;
        expected = "AQ";
      },
      {
        input = "\01\02";
        outputFormat = #standard;
        expected = "AQI=";
      },
      {
        input = "\01\02";
        outputFormat = #url;
        expected = "AQI";
      },
      {
        input = "\FB\FF\FF";
        outputFormat = #standard;
        expected = "+///";
      },
      {
        input = "\FB\FF\FF";
        outputFormat = #url;
        expected = "-___";
      },
      {
        input = "\AA\55\FF";
        outputFormat = #standard;
        expected = "qlX/";
      },
      {
        input = "\AA\55\FF";
        outputFormat = #url;
        expected = "qlX_";
      },
      {
        // Empty string
        input = "";
        outputFormat = #standard;
        expected = "";
      },
      {
        // Single character (requires double padding)
        input = "A";
        outputFormat = #standard;
        expected = "QQ==";
      },
      {
        // Single character URI-safe (no padding)
        input = "A";
        outputFormat = #url;
        expected = "QQ";
      },
      {
        // Two characters (requires single padding)
        input = "BC";
        outputFormat = #standard;
        expected = "QkM=";
      },
      {
        // Two characters URI-safe (no padding)
        input = "BC";
        outputFormat = #url;
        expected = "QkM";
      },
      {
        // Three characters (no padding required)
        input = "DEF";
        outputFormat = #standard;
        expected = "REVG";
      },
      {
        // Special characters
        input = "!@#$%";
        outputFormat = #standard;
        expected = "IUAjJCU=";
      },
      {
        // Binary data with zeros
        input = "\00\01\02\03";
        outputFormat = #standard;
        expected = "AAECAw==";
      },
      {
        // UTF-8 characters (corrected)
        input = "→★♠";
        outputFormat = #standard;
        expected = "4oaS4piF4pmg";
      },
      {
        // Longer text string
        input = "Base64 encoding test 123!";
        outputFormat = #url;
        expected = "QmFzZTY0IGVuY29kaW5nIHRlc3QgMTIzIQ";
      },

      {
        // Mixed case alphanumeric with punctuation
        input = "Hello, World! 123";
        outputFormat = #standard;
        expected = "SGVsbG8sIFdvcmxkISAxMjM=";
      },
      {
        // Special characters that require URI-safe encoding
        input = "~!@#$%^&*()_+{}|:<>?";
        outputFormat = #url;
        expected = "fiFAIyQlXiYqKClfK3t9fDo8Pj8";
      },
      {
        // Multi-byte UTF-8 characters
        input = "日本語";
        outputFormat = #standard;
        expected = "5pel5pys6Kqe";
      },
      {
        // Mix of ASCII and UTF-8
        input = "ABC中文DEF";
        outputFormat = #url;
        expected = "QUJD5Lit5paHREVG";
      },
      {
        // Binary data with pattern
        input = "\01\02\03\04\05\06\07\08";
        outputFormat = #standard;
        expected = "AQIDBAUGBwg=";
      },
      {
        // String length that produces 1 padding character
        input = "12345";
        outputFormat = #standard;
        expected = "MTIzNDU=";
      },
      {
        // Repeating characters
        input = "AAAABBBBCCCC";
        outputFormat = #url;
        expected = "QUFBQUJCQkJDQ0ND";
      },
      {
        // Includes null bytes and other control characters
        input = "\00\01\10\11\20\21";
        outputFormat = #standard;
        expected = "AAEQESAh";
      },
      {
        // Characters that map to different values in base64
        input = "+/=";
        outputFormat = #standard;
        expected = "Ky89";
      },
      {
        // Same characters in URI-safe mode
        input = "+/=";
        outputFormat = #url;
        expected = "Ky89";
      }

    ];
    for (testCase in testCases.vals()) {
      let actual = BaseX.toBase64(testCase.input.vals(), testCase.outputFormat);
      if (actual != testCase.expected) {
        Debug.trap(
          "toBase64 Failure\nValue: " # debug_show (testCase.input) # "\nOutputFormat: " # debug_show (testCase.outputFormat) # "\nExpected: " # testCase.expected # "\nActual:   " # actual
        );
      };
      switch (BaseX.fromBase64(actual)) {
        case (#err(e)) Runtime.trap("Failed to decode base64 value: " # actual # ". Error: " # e);
        case (#ok(actualReverse)) {
          let actualReverseBlob = Blob.fromArray(actualReverse);
          if (actualReverseBlob != testCase.input) {
            Runtime.trap("fromBase64 Failure\nValue: " # debug_show (actual) # "\nOutputFormat: " # debug_show (testCase.outputFormat) # "\nExpected: " # debug_show (testCase.input) # "\nActual:   " # debug_show (actualReverseBlob));
          };
        };
      };
    };
  },
);

test(
  "to/fromHex",
  func() {
    let testCases : [{
      input : Blob;
      outputFormat : BaseX.HexOutputFormat;
      inputFormat : BaseX.HexInputFormat;
      expected : Text;
    }] = [
      {
        // Basic hex encoding, no prefix, uppercase
        input = "\01\02\03\04";
        outputFormat = { isUpper = true; prefix = #none };
        inputFormat = { prefix = #none };
        expected = "01020304";
      },
      {
        // Lowercase hex encoding
        input = "\01\02\03\04";
        outputFormat = { isUpper = false; prefix = #none };
        inputFormat = { prefix = #none };
        expected = "01020304";
      },
      {
        // With 0x prefix
        input = "\01\02\03\04";
        outputFormat = { isUpper = true; prefix = #single("0x") };
        inputFormat = { prefix = #single("0x") };
        expected = "0x01020304";
      },
      {
        // With per-byte \x prefix
        input = "\01\02\03\04";
        outputFormat = { isUpper = true; prefix = #perByte("\\x") };
        inputFormat = { prefix = #perByte("\\x") };
        expected = "\\x01\\x02\\x03\\x04";
      },
      {
        // Empty string
        input = "";
        outputFormat = { isUpper = true; prefix = #none };
        inputFormat = { prefix = #none };
        expected = "";
      },
      {
        // Special characters
        input = "!@#";
        outputFormat = { isUpper = true; prefix = #none };
        inputFormat = { prefix = #none };
        expected = "214023";
      },
      {
        // Single byte
        input = "\FF";
        outputFormat = { isUpper = true; prefix = #none };
        inputFormat = { prefix = #none };
        expected = "FF";
      },
      {
        // Single byte lowercase
        input = "\FF";
        outputFormat = { isUpper = false; prefix = #none };
        inputFormat = { prefix = #none };
        expected = "ff";
      },
      {
        // Multiple bytes with 0x prefix
        input = "\AB\CD\EF";
        outputFormat = { isUpper = true; prefix = #single("0x") };
        inputFormat = { prefix = #single("0x") };
        expected = "0xABCDEF";
      },
      {
        // ASCII text
        input = "Hello";
        outputFormat = { isUpper = true; prefix = #none };
        inputFormat = { prefix = #none };
        expected = "48656C6C6F";
      },
      {
        // UTF-8 characters
        input = "→★♠";
        outputFormat = { isUpper = true; prefix = #none };
        inputFormat = { prefix = #none };
        expected = "E28692E29885E299A0";
      },
      {
        // Different prefix for input and output
        input = "\12\34\56";
        outputFormat = { isUpper = true; prefix = #single("0x") };
        inputFormat = { prefix = #single("0x") };
        expected = "0x123456";
      },
      {
        // Custom prefix
        input = "\12\34\56";
        outputFormat = { isUpper = true; prefix = #single("HEX:") };
        inputFormat = { prefix = #single("HEX:") };
        expected = "HEX:123456";
      },
      {
        // All possible values (0-255)
        input = "\00\01\02\03\04\05\06\07\08\09\0A\0B\0C\0D\0E\0F\10\11\12\13\14\15\16\17\18\19\1A\1B\1C\1D\1E\1F\20\21\22\23\24\25\26\27\28\29\2A\2B\2C\2D\2E\2F\30\31\32\33\34\35\36\37\38\39\3A\3B\3C\3D\3E\3F\40\41\42\43\44\45\46\47\48\49\4A\4B\4C\4D\4E\4F\50\51\52\53\54\55\56\57\58\59\5A\5B\5C\5D\5E\5F\60\61\62\63\64\65\66\67\68\69\6A\6B\6C\6D\6E\6F\70\71\72\73\74\75\76\77\78\79\7A\7B\7C\7D\7E\7F\80\81\82\83\84\85\86\87\88\89\8A\8B\8C\8D\8E\8F\90\91\92\93\94\95\96\97\98\99\9A\9B\9C\9D\9E\9F\A0\A1\A2\A3\A4\A5\A6\A7\A8\A9\AA\AB\AC\AD\AE\AF\B0\B1\B2\B3\B4\B5\B6\B7\B8\B9\BA\BB\BC\BD\BE\BF\C0\C1\C2\C3\C4\C5\C6\C7\C8\C9\CA\CB\CC\CD\CE\CF\D0\D1\D2\D3\D4\D5\D6\D7\D8\D9\DA\DB\DC\DD\DE\DF\E0\E1\E2\E3\E4\E5\E6\E7\E8\E9\EA\EB\EC\ED\EE\EF\F0\F1\F2\F3\F4\F5\F6\F7\F8\F9\FA\FB\FC\FD\FE\FF";
        outputFormat = { isUpper = true; prefix = #none };
        inputFormat = { prefix = #none };
        expected = "000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F202122232425262728292A2B2C2D2E2F303132333435363738393A3B3C3D3E3F404142434445464748494A4B4C4D4E4F505152535455565758595A5B5C5D5E5F606162636465666768696A6B6C6D6E6F707172737475767778797A7B7C7D7E7F808182838485868788898A8B8C8D8E8F909192939495969798999A9B9C9D9E9FA0A1A2A3A4A5A6A7A8A9AAABACADAEAFB0B1B2B3B4B5B6B7B8B9BABBBCBDBEBFC0C1C2C3C4C5C6C7C8C9CACBCCCDCECFD0D1D2D3D4D5D6D7D8D9DADBDCDDDEDFE0E1E2E3E4E5E6E7E8E9EAEBECEDEEEFF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF";
      },
    ];

    for (testCase in testCases.vals()) {
      let actual = BaseX.toHex(testCase.input.vals(), testCase.outputFormat);
      if (actual != testCase.expected) {
        Debug.trap(
          "toHex Failure\nValue: " # debug_show (testCase.input) #
          "\nFormat: " # debug_show (testCase.outputFormat) #
          "\nExpected: " # testCase.expected #
          "\nActual:   " # actual
        );
      };

      switch (BaseX.fromHex(actual, testCase.inputFormat)) {
        case (#err(e)) Runtime.trap(
          "fromHex Failure\nValue: " # debug_show (actual) #
          "\nFormat: " # debug_show (testCase.inputFormat) #
          "\nFailed to decode hex value: " # actual # ". Error: " # e
        );
        case (#ok(actualReverse)) {
          let actualReverseBlob = Blob.fromArray(actualReverse);
          if (actualReverseBlob != testCase.input) {
            Runtime.trap(
              "fromHex Failure\nValue: " # debug_show (actual) #
              "\nFormat: " # debug_show (testCase.inputFormat) #
              "\nExpected: " # debug_show (testCase.input) #
              "\nActual:   " # debug_show (actualReverseBlob)
            );
          };
        };
      };
    };

    // Additional error test cases
    let errorTestCases : [{
      input : Text;
      format : BaseX.HexInputFormat;
      expectedError : Text;
    }] = [
      {
        // Odd length
        input = "123";
        format = { prefix = #none };
        expectedError = "Invalid Value: Hex string must have an even length";
      },
      {
        // Invalid hex character
        input = "12ZZ";
        format = { prefix = #none };
        expectedError = "Invalid Value: Invalid hex character 'Z' at position 2";
      },
      {
        // Missing prefix
        input = "1234";
        format = { prefix = #single("0x") };
        expectedError = "Invalid Value: Hex string must start with prefix '0x'";
      },
      {
        // Invalid per byte format
        input = "\\x12\\y34";
        format = { prefix = #perByte("\\x") };
        expectedError = "Invalid Value: Hex bytes must start with prefix '\\x'";
      },
    ];

    for (errorCase in errorTestCases.vals()) {
      switch (BaseX.fromHex(errorCase.input, errorCase.format)) {
        case (#ok(_)) Runtime.trap(
          "Expected error but got success for input: " # errorCase.input
        );
        case (#err(e)) {
          if (e != errorCase.expectedError) {
            Runtime.trap(
              "Wrong error message for input: " # errorCase.input #
              "\nExpected: " # errorCase.expectedError #
              "\nActual:   " # e
            );
          };
        };
      };
    };
  },
);

test(
  "to/fromBase58",
  func() {
    let testCases : [{ input : Blob; expected : Text }] = [
      {
        // Empty string
        input = "";
        expected = "";
      },
      {
        // Single byte (0)
        input = "\00";
        expected = "1";
      },
      {
        // Multiple zeros (each 0 byte becomes a '1')
        input = "\00\00\00";
        expected = "111";
      },
      {
        // Simple byte sequence
        input = "\01\02\03\04";
        expected = "2VfUX";
      },
      {
        // Simple ASCII text
        input = "Hello";
        expected = "9Ajdvzr";
      },
      {
        // Binary data with pattern
        input = "\FF\FF\FF\FF";
        expected = "7YXq9G";
      },
      {
        // Leading zeros (important edge case in Base58)
        input = "\00\01\02";
        expected = "15T";
      },
      {
        // All decimal digits
        input = "0123456789";
        expected = "3i37NcgooY8f1S";
      },
      {
        // UTF-8 characters
        input = "→★♠";
        expected = "3tEgD35TRY3yH";
      },
      {
        // Longer text
        input = "Base58 is a binary-to-text encoding";
        expected = "7dAJz6PtEcrpxw6yTCFjPTPbCJmQnKR4KFdpQGCtP3oHmCD4";
      },
      {
        // Mix of various bytes
        input = "\00\FF\55\AA\99";
        expected = "17XYcn4";
      },
      {
        // Bitcoin address-like input
        input = "\00\14\7F\F0\D7\4F\38\BD\37\99\12\61\E2\E0\46\73\D1\24\A3\B8\DC";
        expected = "1HZkFdjZaYGgrSN7bt633yn9yCXd";
      },
      {
        // Binary with zeros in middle
        input = "\01\00\00\02";
        expected = "2UzHP";
      },
      {
        // Bytes near alphabet boundaries
        input = "\20\21\57\58";
        expected = "pdoZH";
      },
    ];

    for (testCase in testCases.vals()) {
      let actual = BaseX.toBase58(testCase.input.vals());
      if (actual != testCase.expected) {
        Debug.trap(
          "toBase58 Failure\nValue: " # debug_show (testCase.input) #
          "\nExpected: " # testCase.expected #
          "\nActual:   " # actual
        );
      };

      switch (BaseX.fromBase58(actual)) {
        case (#err(e)) Runtime.trap(
          "Failed to decode base58 value: " # actual # ". Error: " # e
        );
        case (#ok(actualReverse)) {
          let actualReverseBlob = Blob.fromArray(actualReverse);
          if (actualReverseBlob != testCase.input) {
            Runtime.trap(
              "fromBase58 Failure" #
              "\nValue: " # debug_show (actual) #
              "\nExpected: " # debug_show (testCase.input) #
              "\nActual:   " # debug_show (actualReverseBlob)
            );
          };
        };
      };
    };

    // Test error cases for invalid Base58 characters
    let errorTestCases : [{
      input : Text;
      expectedError : Text;
    }] = [
      {
        // Contains invalid character 'O' (capital o)
        input = "O1234567";
        expectedError = "Invalid Base58 character: 'O'";
      },
      {
        // Contains invalid character '0' (zero)
        input = "BC0DEF";
        expectedError = "Invalid Base58 character: '0'";
      },
      {
        // Contains invalid character 'I' (capital i)
        input = "ABCID";
        expectedError = "Invalid Base58 character: 'I'";
      },
      {
        // Contains invalid character 'l' (lowercase L)
        input = "abcl123";
        expectedError = "Invalid Base58 character: 'l'";
      },
      {
        // Contains invalid character '+' (plus)
        input = "abc+def";
        expectedError = "Invalid Base58 character: '+'";
      },
      {
        // Contains invalid character '/' (slash)
        input = "abc/def";
        expectedError = "Invalid Base58 character: '/'";
      },
    ];

    for (errorCase in errorTestCases.vals()) {
      switch (BaseX.fromBase58(errorCase.input)) {
        case (#ok(_)) Runtime.trap(
          "Expected error but got success for input: " # errorCase.input
        );
        case (#err(e)) {
          if (e != errorCase.expectedError) {
            Runtime.trap(
              "Wrong error message for input: " # errorCase.input #
              "\nExpected: " # errorCase.expectedError #
              "\nActual:   " # e
            );
          };
        };
      };
    };
  },
);

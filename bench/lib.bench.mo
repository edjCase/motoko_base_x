import Bench "mo:bench";
import Nat "mo:core@1/Nat";
import Result "mo:core@1/Result";
import Runtime "mo:core@1/Runtime";
import BaseX "../src";

module {
  let base64TextTestData = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5uru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+/w";
  let base32TextTestData = "AAAQEAYEAUDAOCAJBIFQYDIOB4IBCEQTCQKRMFYYDENBWHA5DYPSAIJCEMSCKJRHFAUSUKZMFUXC6MBRGIZTINJWG44DSOR3HQ6T4P2AIFBEGRCFIZDUQSKKJNGE2TSPKBIVEU2UKVLFOWCZLJNVYXK6L5QGCYTDMRSWMZ3INFVGW3DNNZXXA4LSON2HK5TXPB4XU634PV7H7AEBQKBYJBMGQ6EITCULRSGY5D4QSGJJHFEVS2LZRGM2TOOJ3HU7UCQ2FI5EUWTKPKFJVKV2ZLNOV6YLDMVTWS23NN5YXG5LXPF5X274BQOCYPCMLRWHZDE4VS6MZXHM7UGR2LJ5JVOW27MNTWW33TO55X7A4HROHZHF43T6R2PK5PWO33XP6DY7F47U6X3PP6HZ7L57Z7P674======";
  let base58TextTestData = "1HZkFdjZaYGgrSN7bt633yn9yCXd";
  let base16TextTestData : (Text, BaseX.HexInputFormat) = ("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef", { prefix = #none });
  let byteTestData : [Nat8] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255];

  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("BaseX Encoding and Decoding Benchmarks");
    bench.description("Decode a base46 string that decodes to [0, 1, 2, ..., 255] n times");

    bench.rows(["fromBase64", "toBase64", "toBase64UriSafe", "fromBase32", "toBase32", "fromBase16", "toBase16", "fromBase58", "toBase58"]);
    bench.cols(["1", "100", "10000"]);

    bench.runner(
      func(row, col) {
        let ?n = Nat.fromText(col) else Runtime.trap("Cols must only contain numbers: " # col);

        if (row == "fromBase64") {
          for (i in Nat.range(1, n + 1)) {
            let data = BaseX.fromBase64(base64TextTestData);
            assert Result.isOk(data);
          };
        } else if (row == "toBase64") {
          for (i in Nat.range(1, n + 1)) {
            ignore BaseX.toBase64(byteTestData.vals(), #standard({ includePadding = true }));
          };
        } else if (row == "toBase64UriSafe") {
          for (i in Nat.range(1, n + 1)) {
            ignore BaseX.toBase64(byteTestData.vals(), #url({ includePadding = true }));
          };
        } else if (row == "fromBase32") {
          for (i in Nat.range(1, n + 1)) {
            let data = BaseX.fromBase32(base32TextTestData, #standard);
            assert Result.isOk(data);
          };
        } else if (row == "toBase32") {
          for (i in Nat.range(1, n + 1)) {
            ignore BaseX.toBase32(byteTestData.vals(), #standard({ isUpper = true; includePadding = true }));
          };
        } else if (row == "fromBase16") {
          for (i in Nat.range(1, n + 1)) {
            let data = BaseX.fromBase16(base16TextTestData);
            assert Result.isOk(data);
          };
        } else if (row == "toBase16") {
          let outputFormat = {
            isUpper = true;
            prefix = #none;
          };
          for (i in Nat.range(1, n + 1)) {
            ignore BaseX.toBase16(byteTestData.vals(), outputFormat);
          };
        } else if (row == "fromBase58") {
          for (i in Nat.range(1, n + 1)) {
            let data = BaseX.fromBase58(base58TextTestData);
            assert Result.isOk(data);
          };
        } else if (row == "toBase58") {
          for (i in Nat.range(1, n + 1)) {
            ignore BaseX.toBase58(byteTestData.vals());
          };
        } else {
          Runtime.trap("Unknown row: " # row);
        };
      }
    );

    bench;
  };

};

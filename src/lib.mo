import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Nat8 "mo:new-base/Nat8";
import Nat32 "mo:new-base/Nat32";
import Prelude "mo:base/Prelude";
import Buffer "mo:base/Buffer";
import Result "mo:new-base/Result";
import Char "mo:new-base/Char";
import Nat "mo:new-base/Nat";
import List "mo:new-base/List";
import Array "mo:new-base/Array";
import VarArray "mo:new-base/VarArray";
import Runtime "mo:new-base/Runtime";
import Nat16 "mo:new-base/Nat16";
import Prim "mo:⛔";

module {

    public type HexInputFormat = {
        prefix : HexPrefixKind;
    };

    public type HexOutputFormat = {
        isUpper : Bool;
        prefix : HexPrefixKind;
    };

    public type HexPrefixKind = {
        #none;
        #single : Text; // '0x' -> 0xABCD
        #perByte : Text; // '\x' -> \xAB\xCD
    };

    /// Converts a byte iterator to a Base64 encoded text string.
    ///
    /// ```motoko
    /// let data = [0x48, 0x65, 0x6C, 0x6C, 0x6F].vals(); // "Hello" in ASCII
    /// let encoded = toBase64(data, false);
    /// // encoded is "SGVsbG8="
    ///
    /// let uriSafe = toBase64(data, true);
    /// // uriSafe is "SGVsbG8" (no padding, with URI safe characters)
    /// ```
    public func toBase64(data : Iter.Iter<Nat8>, isUriSafe : Bool) : Text {
        var ret = "";
        var remain : Nat32 = 0;
        var bits : Nat32 = 0;
        var bitcount = 0;

        for (byte in data) {
            bitcount += 8;
            let b = Nat32.fromNat(Nat8.toNat(byte));
            remain += 8;
            bits <<= 8;
            bits |= b;

            while (remain >= 6) {
                let index = (bits >> (remain - 6)) & 0x3f;
                let ?base64Char = base64CharFromValue(index, isUriSafe) else Prelude.unreachable();
                ret #= Char.toText(base64Char);
                remain -= 6;
            };

            bits := b & (2 ** remain - 1);
        };

        if (remain != 0) {
            bits <<= (6 - remain);
            let index = bits & 0x3f;
            let ?base64Char = base64CharFromValue(index, isUriSafe) else Prelude.unreachable();
            ret #= Char.toText(base64Char);
        };

        // Add padding for standard Base64
        if (not isUriSafe) {
            let extraBytes = bitcount % 3;
            if (extraBytes > 0) {
                for (_ in Nat.range(0, extraBytes)) ret #= "=";
            };
        };

        ret;
    };

    /// Decodes a Base64 encoded text string to an array of bytes.
    ///
    /// ```motoko
    /// let base64 = "SGVsbG8="; // "Hello" in Base64
    /// let result = fromBase64(base64);
    /// switch (result) {
    ///   case (#ok(bytes)) {
    ///     // bytes is [0x48, 0x65, 0x6C, 0x6C, 0x6F] (ASCII for "Hello")
    ///   };
    ///   case (#err(error)) { /* Handle error */ };
    /// };
    /// ```
    public func fromBase64(text : Text) : Result.Result<[Nat8], Text> {
        // Remove whitespace
        let chars = List.empty<Char>();
        for (c in text.chars()) {
            if (c != ' ' and c != '\n') {
                List.add(chars, c);
            };
        };

        while (List.size(chars) % 4 != 0) {
            List.add(chars, '='); // Add padding if not a multiple of 4
        };
        let charCount = List.size(chars);
        let byteArray = VarArray.repeat<Nat8>(0, (charCount * 3) / 4);

        // Process in blocks of 4 characters
        var iByte = 0;
        for (i in Nat.range(0, charCount / 4)) {
            let blockStart = i * 4;

            // Get the 4 characters in this block
            let c1 = List.get(chars, blockStart);
            let c2 = List.get(chars, blockStart + 1);
            let c3 = List.get(chars, blockStart + 2);
            let c4 = List.get(chars, blockStart + 3);
            if (c1 == '=' or c2 == '=') {
                return #err("Invalid Base64 string: Padding character '=' found in the middle of the string");
            };

            // Convert characters to 6-bit values
            let ?v1 = base64CharToValue(c1) else return #err("Invalid Base64 string: Invalid character '" # Char.toText(c1) # "' at position " # Nat.toText(blockStart));
            let ?v2 = base64CharToValue(c2) else return #err("Invalid Base64 string: Invalid character '" # Char.toText(c2) # "' at position " # Nat.toText(blockStart + 1));
            let ?v3 = base64CharToValue(c3) else return #err("Invalid Base64 string: Invalid character '" # Char.toText(c3) # "' at position " # Nat.toText(blockStart + 2));
            let ?v4 = base64CharToValue(c4) else return #err("Invalid Base64 string: Invalid character '" # Char.toText(c4) # "' at position " # Nat.toText(blockStart + 3));

            // Combine values into bytes

            // Old, without Prim.explodeNat32
            // byteArray[iByte] := Nat8.fromNat(Nat32.toNat((v1 << 2) | (v2 >> 4)));
            // iByte += 1;

            // if (c3 != '=') {
            //     byteArray[iByte] := Nat8.fromNat(Nat32.toNat(((v2 & 0xF) << 4) | (v3 >> 2)));
            //     iByte += 1;

            //     if (c4 != '=') {
            //         byteArray[iByte] := Nat8.fromNat(Nat32.toNat(((v3 & 0x3) << 6) | v4));
            //         iByte += 1;
            //     };
            // };

            let buffer : Nat32 = (v1 << 18) + (v2 << 12) + (v3 << 6) + v4;
            let (_, b1, b2, b3) = Prim.explodeNat32(buffer);
            // Combine values into bytes
            byteArray[iByte] := b1;
            iByte += 1;

            if (c3 != '=') {
                byteArray[iByte] := b2;
                iByte += 1;

                if (c4 != '=') {
                    byteArray[iByte] := b3;
                    iByte += 1;
                };
            };

        };

        #ok(VarArray.sliceToArray(byteArray, 0, iByte));

    };

    /// Converts a byte iterator to a Base16 (hexadecimal) encoded text string.
    /// This is the same as `toHex`
    ///
    /// ```motoko
    /// let data = [0xA1, 0xB2, 0xC3].vals();
    /// let format = { isUpper = true; prefix = #single("0x") };
    /// let encoded : Text = toBase16(data, format);
    /// ```
    public func toBase16(data : Iter.Iter<Nat8>, format : HexOutputFormat) : Text {
        toHex(data, format);
    };

    /// Converts a byte iterator to a hexadecimal encoded text string.
    /// This is the same as `toBase16`
    ///
    /// ```motoko
    /// let data = [0xA1, 0xB2, 0xC3].vals();
    /// let format = { isUpper = false; prefix = #perByte("\\x") };
    /// let encoded : Text = toHex(data, format);
    /// ```
    public func toHex(data : Iter.Iter<Nat8>, format : HexOutputFormat) : Text {
        var result = "";
        let perBytePrefix : ?Text = switch (format.prefix) {
            case (#none) null;
            case (#single(prefix)) {
                result #= prefix;
                null;
            };
            case (#perByte(prefix)) ?prefix;
        };

        for (byte in data) {
            let highNibble = byte / 16;
            let lowNibble = byte % 16;

            let ?highNibbleChar = hexCharFromNibble(highNibble, format.isUpper) else Prelude.unreachable();
            let ?lowNibbleChar = hexCharFromNibble(lowNibble, format.isUpper) else Prelude.unreachable();
            switch (perBytePrefix) {
                case (null) ();
                case (?prefix) {
                    result #= prefix;
                };
            };
            result #= Char.toText(highNibbleChar) # Char.toText(lowNibbleChar);
        };

        result;
    };

    /// Decodes a Base16 (hexadecimal) encoded text string to an array of bytes.
    /// This is the same as `fromHex`
    ///
    /// ```motoko
    /// let hex = "0xA1B2C3";
    /// let format = { prefix = #single("0x") };
    /// let result = fromBase16(hex, format);
    /// switch (result) {
    ///   case (#ok(bytes)) {
    ///     ...
    ///   };
    ///   case (#err(error)) { /* Handle error */ };
    /// };
    /// ```
    public func fromBase16(base16 : Text, format : HexInputFormat) : Result.Result<[Nat8], Text> {
        fromHex(base16, format);
    };

    /// Decodes a hexadecimal encoded text string to an array of bytes.
    /// This is the same as `fromBase16`
    ///
    /// ```motoko
    /// let hex = "\\xa1\\xb2\\xc3";
    /// let format = { prefix = #perByte("\\x") };
    /// let result = fromHex(hex, format);
    /// switch (result) {
    ///   case (#ok(bytes)) {
    ///     ...
    ///   };
    ///   case (#err(error)) { /* Handle error */ };
    /// };
    /// ```
    public func fromHex(hex : Text, format : HexInputFormat) : Result.Result<[Nat8], Text> {
        let input : [Char] = switch (format.prefix) {
            case (#none) Text.toArray(hex);
            case (#single(prefix)) {
                let ?realHex = Text.stripStart(hex, #text(prefix)) else return #err("Invalid Value: Hex string must start with prefix '" # prefix # "'");
                Text.toArray(realHex);
            };
            case (#perByte(prefix)) {
                let parts = Text.split(hex, #text(prefix));
                var inputBuffer = Buffer.Buffer<Char>(hex.size());
                label f for (part in parts) {
                    if (Text.size(part) != 2) {
                        if (Text.size(part) == 0) {
                            continue f; // skip empty parts
                        };
                        return #err("Invalid Value: Hex bytes must start with prefix '" # prefix # "'");
                    };
                    let partIter = part.chars();
                    let ?firstChar = partIter.next() else Prelude.unreachable();
                    let ?secondChar = partIter.next() else Prelude.unreachable();
                    inputBuffer.add(firstChar);
                    inputBuffer.add(secondChar);
                };
                Buffer.toArray(inputBuffer);
            };
        };

        // Check for even length
        if (input.size() % 2 != 0) {
            return #err("Invalid Value: Hex string must have an even length");
        };

        let bytes = VarArray.repeat<Nat8>(0, input.size() / 2);

        var i = 0;
        while (i < input.size()) {
            let ?highNibble = hexCharToNibble(input[i]) else return #err("Invalid Value: Invalid hex character '" # Char.toText(input[i]) # "' at position " # Nat.toText(i));
            let ?lowNibble = hexCharToNibble(input[i + 1]) else return #err("Invalid Value: Invalid hex character '" # Char.toText(input[i + 1]) # "' at position " # Nat.toText(i + 1));

            let byte = highNibble * 16 + lowNibble;
            bytes[i / 2] := byte;
            i += 2;
        };

        #ok(Array.fromVarArray(bytes));
    };

    /// Converts a byte iterator to a Base58 encoded text string.
    ///
    /// ```motoko
    /// let data = [0x00, 0x01, 0x02].vals();
    /// let encoded : Text = toBase58(data);
    /// ```
    public func toBase58(bytes : Iter.Iter<Nat8>) : Text {
        // Convert to array for easier processing
        let bytesArray = Iter.toArray(bytes);
        let size = bytesArray.size();

        // Handle empty input
        if (size == 0) {
            return "";
        };

        // Count leading zeros
        var zeros = 0;
        while (zeros < size and bytesArray[zeros] == 0) {
            zeros += 1;
        };

        // If input is all zeros, return all '1's
        if (zeros == size) {
            var result = "";
            for (_ in Nat.range(0, zeros)) {
                result #= "1";
            };
            return result;
        };

        // Preallocate the work buffer
        let b58 = VarArray.repeat<Nat32>(0, size * 2);
        var b58Size = 0;

        // OPTIMIZATION: Use precomputed powers to avoid overflow
        let powers : [Nat32] = [1, 256, 65536, 16777216]; // 256^0, 256^1, 256^2, 256^3

        // Process bytes in batches of up to 3 (not 4!) to avoid overflow
        var i = zeros;
        while (i < size) {
            // Process up to 3 bytes at once (not 4) to avoid Nat32 overflow
            var batchSize = Nat.min(3, size - i);

            // Combine bytes into a single value
            var combined : Nat32 = 0;
            for (j in Nat.range(0, batchSize)) {
                combined := combined * 256 + Nat32.fromNat(Nat8.toNat(bytesArray[i + j]));
            };

            var j = 0;
            // Apply the combined value to existing digits
            while (j < b58Size or combined > 0) {
                if (j < b58Size) {
                    // Use precomputed power value to avoid overflow
                    combined += b58[j] * powers[batchSize];
                };

                b58[j] := combined % 58;
                combined := combined / 58;

                j += 1;
            };

            b58Size := j;
            i += batchSize;
        };

        // Create result buffer
        let result = Buffer.Buffer<Char>(size * 2);

        // Add leading '1's for zeros
        for (_ in Nat.range(0, zeros)) {
            result.add('1');
        };

        // Add the encoded characters in reverse order
        for (i in Nat.range(0, b58Size)) {
            let index : Nat = b58Size - 1 - i;
            let ?c = base58CharFromValue(Nat32.toNat(b58[index])) else Prelude.unreachable();
            result.add(c);
        };

        return Text.fromIter(result.vals());
    };

    /// Decodes a Base58 encoded text string to an array of bytes.
    ///
    /// ```motoko
    /// let base58 = "2UzHP";
    /// let result = fromBase58(base58);
    /// switch (result) {
    ///   case (#ok(bytes)) {
    ///     ...
    ///   };
    ///   case (#err(error)) { /* Handle error */ };
    /// };
    /// ```
    public func fromBase58(text : Text) : Result.Result<[Nat8], Text> {
        if (text.size() == 0) {
            return #ok([]);
        };

        // Process the characters (excluding leading '1's)
        var currentValue : Nat = 0;
        var zeros = 0;
        var valueStarted = false;
        label f for (char in text.chars()) {
            if (not valueStarted) {
                if (char == '1') {
                    zeros += 1;
                    continue f; // Skip leading '1's
                };
                valueStarted := true;
            };
            // Get value for this character
            let ?digitValue = base58CharToValue(char) else return #err("Invalid Base58 character: '" # Char.toText(char) # "'");

            // Multiply existing result by 58 and add new digit
            currentValue *= 58;
            currentValue += digitValue;
        };

        // Create output buffer
        let bytes = Buffer.Buffer<Nat8>(text.size() * 2); // Conservative estimate

        while (currentValue > 0) {
            // Get the next byte
            let byte = Nat8.fromNat(currentValue % 256);
            bytes.add(byte);
            currentValue /= 256;
        };
        // Add zeros for leading '1's - use explicit loop instead of Nat.range
        for (_ in Nat.range(0, zeros)) {
            bytes.add(0);
        };

        // Reverse the result
        Buffer.reverse(bytes);

        #ok(Buffer.toArray(bytes));
    };
    // Precomputed lookup table for Base58 character to value conversion (index = ASCII value, value = Base58 value or null)
    // Base58 character to value table (123 elements)
    let base58CharToValueTable : [?Nat] = [null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, ?0, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, null, null, null, null, null, null, null, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, null, ?17, ?18, ?19, ?20, ?21, null, ?22, ?23, ?24, ?25, ?26, ?27, ?28, ?29, ?30, ?31, ?32, null, null, null, null, null, null, ?33, ?34, ?35, ?36, ?37, ?38, ?39, ?40, ?41, ?42, ?43, null, ?44, ?45, ?46, ?47, ?48, ?49, ?50, ?51, ?52, ?53, ?54, ?55, ?56, ?57];

    // Base58 value to character table (58 elements)
    let base58ValueToCharTable : [Char] = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'];

    // Optimized function for Base58 character to value conversion
    private func base58CharToValue(c : Char) : ?Nat {
        let charCode = Nat32.toNat(Char.toNat32(c));
        if (charCode >= base58CharToValueTable.size()) {
            return null;
        };
        base58CharToValueTable[charCode];
    };

    // Optimized function for Base58 value to character conversion
    private func base58CharFromValue(value : Nat) : ?Char {
        if (value >= base58ValueToCharTable.size()) {
            return null;
        };
        ?base58ValueToCharTable[value];
    };

    let charToValueTable : [?Nat32] = [null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, ?62, null, ?62, null, ?63, ?52, ?53, ?54, ?55, ?56, ?57, ?58, ?59, ?60, ?61, null, null, null, null, null, null, null, ?0, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22, ?23, ?24, ?25, null, null, null, null, ?63, null, ?26, ?27, ?28, ?29, ?30, ?31, ?32, ?33, ?34, ?35, ?36, ?37, ?38, ?39, ?40, ?41, ?42, ?43, ?44, ?45, ?46, ?47, ?48, ?49, ?50, ?51];

    // Helper function for base64 decoding
    private func base64CharToValue(c : Char) : ?Nat32 {
        if (c == '=') {
            return ?0; // Padding character
        };

        let charCode = Nat32.toNat(Char.toNat32(c));
        if (charCode >= charToValueTable.size()) {
            return null;
        };
        charToValueTable[charCode];
    };
    // Standard base64 character lookup table (values 0-63)
    let valueToCharTable : [Char] = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/'];

    // URI-safe version table (only different at positions 62 and 63)
    let valueToCharTableUriSafe : [Char] = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '-', '_'];

    private func base64CharFromValue(value : Nat32, isUriSafe : Bool) : ?Char {
        if (value >= 64) {
            return null;
        };

        // Convert to Nat for array indexing
        let index = Nat32.toNat(value);

        // Use the appropriate lookup table based on isUriSafe
        if (isUriSafe) {
            return ?valueToCharTableUriSafe[index];
        } else {
            return ?valueToCharTable[index];
        };
    }; // Precomputed lookup table for hex character to nibble conversion (index = ASCII value, value = hex value or null)
    let hexCharToNibbleTable : [?Nat8] = [null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, ?0, ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, /* 48-57: '0'-'9' */ null, null, null, null, null, null, null, ?10, ?11, ?12, ?13, ?14, ?15, /* 65-70: 'A'-'F' */ null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, ?10, ?11, ?12, ?13, ?14, ?15 /* 97-102: 'a'-'f' */];

    // Precomputed lookup tables for nibble to hex character conversion
    let hexNibbleToLowerTable : [Char] = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'];
    let hexNibbleToUpperTable : [Char] = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'];

    // Optimized function for hex character to nibble conversion
    private func hexCharToNibble(c : Char) : ?Nat8 {
        let charCode = Nat32.toNat(Char.toNat32(c));
        if (charCode >= hexCharToNibbleTable.size()) {
            return null;
        };
        hexCharToNibbleTable[charCode];
    };

    // Optimized function for nibble to hex character conversion
    private func hexCharFromNibble(value : Nat8, isUpper : Bool) : ?Char {
        if (value >= 16) {
            return null;
        };
        if (isUpper) {
            ?hexNibbleToUpperTable[Nat8.toNat(value)];
        } else {
            ?hexNibbleToLowerTable[Nat8.toNat(value)];
        };
    };
};

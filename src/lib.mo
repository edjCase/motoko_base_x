import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Nat8 "mo:new-base/Nat8";
import Nat32 "mo:new-base/Nat32";
import Buffer "mo:base/Buffer";
import Prelude "mo:base/Prelude";
import Result "mo:new-base/Result";
import Char "mo:new-base/Char";
import Nat "mo:new-base/Nat";

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

    // Base64 Functions
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

    public func fromBase64(text : Text) : Result.Result<[Nat8], Text> {
        // Remove whitespace
        let chars = Buffer.Buffer<Char>(text.size());
        for (c in text.chars()) {
            if (c != ' ' and c != '\n') {
                chars.add(c);
            };
        };

        while (chars.size() % 4 != 0) {
            chars.add('='); // Add padding if not a multiple of 4
        };
        let cleanInput = Buffer.toArray(chars);

        let output = Buffer.Buffer<Nat8>((cleanInput.size() * 3) / 4);

        // Process in blocks of 4 characters
        for (i in Nat.range(0, cleanInput.size() / 4)) {
            let blockStart = i * 4;

            // Get the 4 characters in this block
            let c1 = cleanInput[blockStart];
            let c2 = cleanInput[blockStart + 1];
            let c3 = cleanInput[blockStart + 2];
            let c4 = cleanInput[blockStart + 3];
            if (c1 == '=' or c2 == '=') {
                return #err("Invalid Base64 string: Padding character '=' found in the middle of the string");
            };

            // Convert characters to 6-bit values
            let ?v1 = base64CharToValue(c1) else return #err("Invalid Base64 string: Invalid character '" # Char.toText(c1) # "' at position " # Nat.toText(blockStart));
            let ?v2 = base64CharToValue(c2) else return #err("Invalid Base64 string: Invalid character '" # Char.toText(c2) # "' at position " # Nat.toText(blockStart + 1));
            let ?v3 = base64CharToValue(c3) else return #err("Invalid Base64 string: Invalid character '" # Char.toText(c3) # "' at position " # Nat.toText(blockStart + 2));
            let ?v4 = base64CharToValue(c4) else return #err("Invalid Base64 string: Invalid character '" # Char.toText(c4) # "' at position " # Nat.toText(blockStart + 3));

            // Combine values into bytes
            output.add(Nat8.fromNat(Nat32.toNat((v1 << 2) | (v2 >> 4))));

            if (c3 != '=') {
                output.add(Nat8.fromNat(Nat32.toNat(((v2 & 0xF) << 4) | (v3 >> 2))));

                if (c4 != '=') {
                    output.add(Nat8.fromNat(Nat32.toNat(((v3 & 0x3) << 6) | v4)));
                };
            };
        };

        #ok(Buffer.toArray(output));
    };

    // Hex Functions

    public func toBase16(data : Iter.Iter<Nat8>, format : HexOutputFormat) : Text {
        toHex(data, format);
    };

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

    public func fromBase16(base16 : Text, format : HexInputFormat) : Result.Result<[Nat8], Text> {
        fromHex(base16, format);
    };

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

        let buffer = Buffer.Buffer<Nat8>(input.size() / 2);

        var i = 0;
        while (i < input.size()) {
            let ?highNibble = hexCharToNibble(input[i]) else return #err("Invalid Value: Invalid hex character '" # Char.toText(input[i]) # "' at position " # Nat.toText(i));
            let ?lowNibble = hexCharToNibble(input[i + 1]) else return #err("Invalid Value: Invalid hex character '" # Char.toText(input[i + 1]) # "' at position " # Nat.toText(i + 1));

            let byte = highNibble * 16 + lowNibble;
            buffer.add(byte);
            i += 2;
        };

        #ok(Buffer.toArray(buffer));
    };

    // Helper function for base64 decoding
    private func base64CharToValue(c : Char) : ?Nat32 {
        let natValue : Nat32 = switch (c) {
            case ('A') 0;
            case ('B') 1;
            case ('C') 2;
            case ('D') 3;
            case ('E') 4;
            case ('F') 5;
            case ('G') 6;
            case ('H') 7;
            case ('I') 8;
            case ('J') 9;
            case ('K') 10;
            case ('L') 11;
            case ('M') 12;
            case ('N') 13;
            case ('O') 14;
            case ('P') 15;
            case ('Q') 16;
            case ('R') 17;
            case ('S') 18;
            case ('T') 19;
            case ('U') 20;
            case ('V') 21;
            case ('W') 22;
            case ('X') 23;
            case ('Y') 24;
            case ('Z') 25;

            case ('a') 26;
            case ('b') 27;
            case ('c') 28;
            case ('d') 29;
            case ('e') 30;
            case ('f') 31;
            case ('g') 32;
            case ('h') 33;
            case ('i') 34;
            case ('j') 35;
            case ('k') 36;
            case ('l') 37;
            case ('m') 38;
            case ('n') 39;
            case ('o') 40;
            case ('p') 41;
            case ('q') 42;
            case ('r') 43;
            case ('s') 44;
            case ('t') 45;
            case ('u') 46;
            case ('v') 47;
            case ('w') 48;
            case ('x') 49;
            case ('y') 50;
            case ('z') 51;

            case ('0') 52;
            case ('1') 53;
            case ('2') 54;
            case ('3') 55;
            case ('4') 56;
            case ('5') 57;
            case ('6') 58;
            case ('7') 59;
            case ('8') 60;
            case ('9') 61;

            case ('+') 62;
            case ('/') 63;
            case ('-') 62; // URI-safe alternative to '+'
            case ('_') 63; // URI-safe alternative to '/'
            case ('=') 0; // Padding character

            case (_) return null;
        };
        ?natValue;
    };

    // Convert number to base64 character
    public func base64CharFromValue(value : Nat32, isUriSafe : Bool) : ?Char {
        let char : Char = switch (value) {
            case (0) 'A';
            case (1) 'B';
            case (2) 'C';
            case (3) 'D';
            case (4) 'E';
            case (5) 'F';
            case (6) 'G';
            case (7) 'H';
            case (8) 'I';
            case (9) 'J';
            case (10) 'K';
            case (11) 'L';
            case (12) 'M';
            case (13) 'N';
            case (14) 'O';
            case (15) 'P';
            case (16) 'Q';
            case (17) 'R';
            case (18) 'S';
            case (19) 'T';
            case (20) 'U';
            case (21) 'V';
            case (22) 'W';
            case (23) 'X';
            case (24) 'Y';
            case (25) 'Z';
            case (26) 'a';
            case (27) 'b';
            case (28) 'c';
            case (29) 'd';
            case (30) 'e';
            case (31) 'f';
            case (32) 'g';
            case (33) 'h';
            case (34) 'i';
            case (35) 'j';
            case (36) 'k';
            case (37) 'l';
            case (38) 'm';
            case (39) 'n';
            case (40) 'o';
            case (41) 'p';
            case (42) 'q';
            case (43) 'r';
            case (44) 's';
            case (45) 't';
            case (46) 'u';
            case (47) 'v';
            case (48) 'w';
            case (49) 'x';
            case (50) 'y';
            case (51) 'z';
            case (52) '0';
            case (53) '1';
            case (54) '2';
            case (55) '3';
            case (56) '4';
            case (57) '5';
            case (58) '6';
            case (59) '7';
            case (60) '8';
            case (61) '9';
            case (62) if (isUriSafe) '-' else '+';
            case (63) if (isUriSafe) '_' else '/';
            case (_) return null;
        };
        ?char;
    };

    // Helper function for hex conversion
    private func hexCharToNibble(c : Char) : ?Nat8 {
        let natValue : Nat8 = switch (c) {
            case ('0') 0;
            case ('1') 1;
            case ('2') 2;
            case ('3') 3;
            case ('4') 4;
            case ('5') 5;
            case ('6') 6;
            case ('7') 7;
            case ('8') 8;
            case ('9') 9;
            case ('a' or 'A') 10;
            case ('b' or 'B') 11;
            case ('c' or 'C') 12;
            case ('d' or 'D') 13;
            case ('e' or 'E') 14;
            case ('f' or 'F') 15;
            case (_) return null;
        };
        ?natValue;
    };

    // Convert number to hex character
    public func hexCharFromNibble(value : Nat8, isUpper : Bool) : ?Char {
        let char : Char = switch (value) {
            case (0) '0';
            case (1) '1';
            case (2) '2';
            case (3) '3';
            case (4) '4';
            case (5) '5';
            case (6) '6';
            case (7) '7';
            case (8) '8';
            case (9) '9';
            case (10) if (isUpper) 'A' else 'a';
            case (11) if (isUpper) 'B' else 'b';
            case (12) if (isUpper) 'C' else 'c';
            case (13) if (isUpper) 'D' else 'd';
            case (14) if (isUpper) 'E' else 'e';
            case (15) if (isUpper) 'F' else 'f';
            case (_) return null;
        };
        ?char;
    };

};

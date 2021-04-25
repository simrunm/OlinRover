classdef UBX
    % used in support of NEO_M8U.m
    % PLEASE DO NOT EDIT THIS CODE!
    % Copyright Olin Robot Lab 2021
    properties (Constant)
        %sync characters for messages
        sync_char_1 = 0xB5;
        sync_char_2 = 0x62;
        %sync_chars = [sync_char_1 sync_char_2];
        
        %     class code-name mappings, from page 173-179:
        %     https://hex2dec(0xb5www.u-blox.com/sites/default/files/products/documents/u-blox8-M8_ReceiverDescrProtSpec_UBX-13003221.pdf
        %class_code = struct('NAV',0x01,'RXM', 0x02,'INF', 0x04,'ACK', 0x05,'CFG', 0x06,'UPD', 0x09,'MON', 0x0A,'AID', 0x0B,'TIM', 0x0D,'ESF', 0x10,'MGA', 0x13,'LOG', 0x21,'SEC', 0x27,'HNR', 0x28);
        CLASS_ID = UBX_CLASS_ID();
    end
    properties
    %    frame = struct('sync_chars',2,'identifier_bytes',2,'length_bytes' 2, 'end_bytes',2,'little_endian',1);
    end
    methods
        function obj = UBX()
        end       
        function messages = parseIndividualMsgs (obj, raw_data)
            i=1;
            messages = struct();
            while (i<raw_data.length)
                clear msg;
                % determine each msg length;
                %there are 8 non-payload bytes in every UBX frame: 2x sync chars, class_id, payload_length, 2x checksum
                msg.length = uint64(raw_data.bytes(i+4)+256*raw_data.bytes(i+5)+8); %uint64 ensures no error if length > 255
                msg.bytes = raw_data.bytes(i:i+msg.length-1);
                
                i = i + msg.length;
                % decode each message
                
                decoded_msg = obj.decode(msg.bytes);
                
                % add msg to messages struct
                messages.(decoded_msg.class_id) = obj.parse(decoded_msg);
            end
        end
        function checksum = checksum(obj, msg_core)
            check_a = 0;
            check_b = 0;
            
            for i=(1:length(msg_core))
                check_a = check_a + msg_core(i);
                check_b = check_b + check_a;
            end
            %[check_a check_b]; %debugging
            mask = [typecast(uint64(check_a),'uint8'); typecast(uint64(check_b),'uint8')];
            checksum = [mask(1,1) mask(2,1)];
        end
        function message = decode(obj, ubx_message)
            %ubx_message %for debugging
            
            %message structure: [s1 s21 class id length_high length_low, p1...pN c_a c_b]
            message.sync_chars = ubx_message(1:2);
            message.class_id = obj.CLASS_ID.lookup(ubx_message(3:4));
            message.length = 256*ubx_message(5)+ubx_message(6);
            message.payload = ubx_message(7:end-2);
            message.cs = ubx_message(end-1:end);
            message.cs_calc = obj.checksum([message.class_id message.length message.payload]);
        end
        %parsing functions for decoded data
        function pvt = parse_NAV_PVT(obj,message)
            pvt.iTOW = typecast(uint8(message.payload(1:4)), 'uint32');
            pvt.year = typecast(uint8(message.payload(5:6)), 'uint16');
            pvt.month = uint8(message.payload(7));
            pvt.day = uint8(message.payload(8));
            pvt.hour = uint8(message.payload(9));
            pvt.minute = uint8(message.payload(10));
            pvt.second = uint8(message.payload(11));
            pvt.valid = dec2bin(message.payload(12)); %binary bitfield
            pvt.tAcc = typecast(uint8(message.payload(13:16)), 'uint32');
            pvt.nano = typecast(uint8(message.payload(17:20)), 'int32');
            pvt.fixType = obj.parseFix(uint8(message.payload(21)));
            pvt.flags = dec2bin(message.payload(22)); %binary bitfield
            pvt.flags2 = dec2bin(message.payload(23)); %binary bitfield
            pvt.numSV = uint8(message.payload(24));
            pvt.lon = double(typecast(uint8(message.payload(25:28)), 'int32'))*10^-7;
            pvt.lat = double(typecast(uint8(message.payload(29:32)), 'int32'))*10^-7;
            % more data exists, but is not required at this time. 
        end
        function sol = parse_NAV_SOL(obj,message)
            sol.iTOW = typecast(uint8(message.payload(1:4)), 'uint32');
            sol.fTOW = typecast(uint8(message.payload(5:8)), 'int32');
            sol.week = typecast(uint8(message.payload(9:10)), 'int16');
            sol.gpsFix = obj.parseFix(uint8(message.payload(11)));
            sol.flags = dec2bin(message.payload(12)); %binary bitfield
            sol.ecefX = typecast(uint8(message.payload(13:16)),'int32');
            sol.ecefY = typecast(uint8(message.payload(17:20)),'int32');
            sol.ecefZ = typecast(uint8(message.payload(21:24)),'int32');
            sol.pAcc = typecast(uint8(message.payload(25:28)),'uint32');
            sol.ecefVX = typecast(uint8(message.payload(29:32)),'int32');
            sol.ecefVY = typecast(uint8(message.payload(33:36)),'int32');
            sol.ecefVZ = typecast(uint8(message.payload(37:40)),'int32');
            sol.sAcc = typecast(uint8(message.payload(41:44)),'uint32');
            sol.pDOP = 0.1*typecast(uint8(message.payload(45:46)),'uint16');
            sol.reserved1 = uint8(message.payload(47));
            sol.numSV = uint8(message.payload(48));
            sol.reserved2 = message.payload(49:52);
        end
        function att = parse_NAV_ATT(obj,message)
            att.iTOW = typecast(uint8(message.payload(1:4)), 'uint32');
            att.version = uint8(message.payload(5));
            att.reserved1 = uint8(message.payload(6:8));
            att.roll = double(typecast(uint8(message.payload(9:12)), 'int32'))*10^-5;
            att.pitch = double(typecast(uint8(message.payload(13:16)), 'int32'))*10^-5;
            att.heading = double(typecast(uint8(message.payload(17:20)), 'int32'))*10^-5;
            att.accRoll = double(typecast(uint8(message.payload(21:24)), 'uint32'))*10^-5;
            att.accPitch = double(typecast(uint8(message.payload(25:28)), 'uint32'))*10^-5;
            att.accHeading = double(typecast(uint8(message.payload(29:32)), 'uint32'))*10^-5;
            
        end
        function status = parse_NAV_STATUS(obj,message)
            status.iTOW = typecast(uint8(message.payload(1:4)), 'uint32');
            status.gpsFix = obj.parseFix(uint8(message.payload(5)));
            status.flags = dec2bin(message.payload(6)); %binary bitfield
            status.fixStat = dec2bin(message.payload(7)); %binary bitfield
            status.flags2 = dec2bin(message.payload(8)); %binary bitfield
            status.ttff = typecast(uint8(message.payload(9:12)), 'uint32');
            status.msss = typecast(uint8(message.payload(13:16)), 'uint32');
        end
        function fix = parseFix(obj, fix_code)
            switch fix_code
                case 0
                    fix = 'No Fix';
                case 1
                    fix = 'Dead Reckoning Only';
                case 2
                    fix = '2D Fix';
                case 3
                    fix = '3D Fix';
                case 4
                    fix = 'GPS + Dead Reckoning';
                case 5
                    fix = 'Time Only Fix';
                otherwise
                    fix = 'Invalid Fix Code: '+string(fix_code);
            end
        end
        function msg = parse(obj, message)
            msg = obj.(strcat('parse_',message.class_id))(message);
        end
    end
end
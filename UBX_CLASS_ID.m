classdef UBX_CLASS_ID
    % used in support of NEO_M8U.m
    % PLEASE DO NOT EDIT THIS CODE!
    % Copyright Olin Robot Lab 2021
    properties
        %Acknowledge class-id pairs
        ACK_ACK = struct('class_id',[0x05 0x00],'length',2);
        ACK_NAK = struct('class_id',[0x05 0x01],'length',2);
        
        %Navigation class-id pairs
        NAV_ATT = struct('class_id',[0x01 0x05],'length',32);
        NAV_HPPOSLLH = struct('class_id',[0x01 0x14],'length',36);
        NAV_STATUS = struct('class_id',[0x01 0x03],'length',16);
        NAV_SOL = struct('class_id',[0x01 0x06],'length',52);
        NAV_PVT = struct('class_id',[0x01 0x07],'length',92);
        
        %High Rate Navigation pairs
        HNR_PVT = struct('class_id',[0x28 0x00],'length',72);
        HNR_ATT = struct('class_id',[0x28 0x01],'length',32);
               
        %Config class-id pairs
        CFG_PRT = struct('class_id',[0x06 0x00],'length',20);
        CFG_MSG = struct('class_id',[0x06 0x01],'length',3);
        
    end
    methods
        function obj = UBX_CLASS_ID()
        end
        function message_name = lookup(obj, class_id)
            switch typecast(uint8(class_id),'uint16')
                case typecast(uint8([0x05 0x00]),'uint16')
                    message_name = 'ACK_ACK';
                case typecast(uint8([0x05 0x01]),'uint16')
                    message_name = 'ACK_NAK';
                case typecast(uint8([0x06 0x00]),'uint16')
                    message_name = 'CFG_PRT';
                case typecast(uint8([0x01 0x03]),'uint16')
                    message_name = 'NAV_STATUS';
                case typecast(uint8([0x01 0x05]),'uint16')
                    message_name = 'NAV_ATT';
                case typecast(uint8([0x01 0x06]),'uint16')
                    message_name = 'NAV_SOL';
                case typecast(uint8([0x01 0x07]),'uint16')
                    message_name = 'NAV_PVT';
                case typecast(uint8([0x01 0x14]),'uint16')
                    message_name = 'NAV_HPPOSLLH';
                case typecast(uint8([0x28 0x00]),'uint16')
                    message_name = 'HNR_PVT';
                case typecast(uint8([0x28 0x01]),'uint16')
                    message_name = 'HNR_ATT';
                otherwise
                    message_name = 'Class_Id not recognized'+string(class_id);
            end
        end
    end
end
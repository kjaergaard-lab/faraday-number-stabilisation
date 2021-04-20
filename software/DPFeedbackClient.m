classdef DPFeedbackClient < handle
    %DPFeedbackClient Defines a class for handling client-side
    %communication with a server via the TCP/IP protocol
    properties
        client  %Client tcpip() object
        host    %Address of the socket server to connect to 
    end
    
    properties(SetAccess = protected)
        headerLength    %Length of message header in bytes
        header          %Actual header
        recvMessage     %Received message
        recvDone        %Flag indicating that message has been received in its entirety
        bytesRead       %Number of bytes read from the server
    end
    
    properties(Constant)
        TCP_PORT = 6666;                %TCP Port to use
        HOST_ADDRESS = '172.22.250.94'; %Default server IP address
    end
    
    methods
        function self = DPFeedbackClient(host)
            %DPFEEDBACKCLIENT Creates an instance of the object with
            %default host address
            %
            %   CONN = DPFEEDBACKCLIENT() Creates an instance of the object
            %   with the default host address
            %
            %   CONN = DPFEEDBACKCLIENT(HOST) creates an instance with the
            %   specified IP address/server name HOST
            if nargin==1
                self.host = host;
            else
                self.host = self.HOST_ADDRESS;
            end
            self.initRead;
        end
        
        function open(self)
            %OPEN Creates and opens a TCP/IP connection
            r = instrfindall('RemoteHost',self.host,'RemotePort',self.TCP_PORT);
            if isempty(r)
                self.client = tcpip(self.host,self.TCP_PORT,'byteOrder','littleEndian');
                self.client.InputBufferSize = 2^20;
                fopen(self.client);
            elseif strcmpi(r.Status,'closed')
                self.client = r;
                self.client.InputBufferSize = 2^20;
                fopen(self.client);
            else
                self.client = r;
            end
                
        end
        
        function close(self)
            %CLOSE Closes and deletes the TCP/IP object associated with
            %this instance
            if ~isempty(self.client) && isvalid(self.client) && strcmpi(self.client,'open')
                fclose(self.client);
            end
            delete(self.client);
            self.client = [];
        end
        
        function delete(self)
            %DELETE Deletes this object by first closing the TCP/IP
            %connection
            try
                self.close;
            catch
                disp('Error deleting client');
            end
        end
        
        function initRead(self)
            %INITREAD Initializes the reception of messages from the server
            self.headerLength = [];
            self.header = [];
            self.recvMessage = [];
            self.recvDone = false;
            self.bytesRead = 0;
        end
        
        function self = write(self,data,varargin)
            %WRITE Writes data to the server
            %
            %   FB = FB.WRITE(DATA,NAME1,VALUE1,NAME2,VALUE2,...) writes
            %   DATA to the server with message header fields given by
            %   (NAME1,VALUE1), (NAME2,VALUE2), etc.  The message header is
            %   converted into a JSON formatted string before being sent,
            %   and the DATA is converted into an array of uint8 integers
            %
            %   WRITE expects a reply and will wait for up to 20 s for a
            %   reply
            
            if mod(numel(varargin),2)~=0
                error('Variable arguments must be in name/value pairs');
            end
            %If no data is provided, write a zero to the server as it
            %expects some data
            if numel(data) == 0
                data = 0;
            end
            %Open the connection
            self.open;
            
            try
                %Create message header MSG
                msg.length = numel(data);
                for nn=1:2:numel(varargin)
                    msg.(varargin{nn}) = varargin{nn+1};
                end

                self.initRead;              %Reset the read variables
                msg = jsonencode(msg);      %Encode the header as a JSON string
                len = uint16(numel(msg));   %Determine the header length

                %Send the message as header length (2 bytes), header, data
                msg_write = [typecast(len,'uint8'),uint8(msg),typecast(uint32(data),'uint8')];
                fwrite(self.client,msg_write,'uint8');
                
                %Hacked-together read process that has a well-defined
                %timeout of 20 s. Exits when recvDone flag is true
                jj = 1;
                while ~self.recvDone
                    self.read;      %This does the actual processing of the message
                    %The rest of this while loop waits for at most 20 s
                    %before throwing an error
                    pause(10e-3);
                    if jj>2e3
                        error('Timeout reading data');
                    else
                        jj = jj+1;
                    end
                end
                self.close
            catch e
                self.close;
                rethrow(e);
            end
        end
        
        function read(self)
            %READ Reads a reply from the server
            
            %If header length is unknown, get it from the message
            if isempty(self.headerLength)
                self.processProtoHeader();
            end
            
            %If the header is empty, get it from the message
            if isempty(self.header)
                self.processHeader();
            end
            
            %If there should be data, and we have not finished reading the
            %message, retrieve the data from the message
            if isfield(self.header,'length') && ~self.recvDone
                self.processMessage();
            end
        end
    end
    
    methods(Access = protected)       
        function processProtoHeader(self)
            %PROCESSPROTOHEADER Retrieves the header length from the first
            %two bytes of the message
            if self.client.BytesAvailable>=2
                self.headerLength = fread(self.client,1,'uint16');
            end
        end
        
        function processHeader(self)
            %PROCESSHEADER Retrieves the header from the message based on
            %the header length acquired from PROCESSPROTOHEADER.
            %
            %   The header is assumed to be a JSON formatted character
            %   vector
            if self.client.BytesAvailable>=self.headerLength
                tmp = fread(self.client,self.headerLength,'uint8');
                self.header = jsondecode(char(tmp)');
                if ~isfield(self.header,'length')
                    self.recvDone = true;
                end
            end
        end
        
        function processMessage(self)
            %PROCESSMESSAGE Retrieves the message data from the message
            %based on the header, specifically the "length" field in the
            %header
            if self.bytesRead < self.header.length
                bytesToRead = self.client.BytesAvailable;
%                 fprintf(1,'Bytes to read: %d\n',bytesToRead);
                tmp = uint8(fread(self.client,bytesToRead,'uint8'));
%                 fprintf(1,'Bytes read: %d\n',numel(tmp));
                self.recvMessage = [self.recvMessage;tmp];
                self.bytesRead = numel(self.recvMessage);
%                 fprintf(1,'Total bytes read: %d\n',self.bytesRead);
            end
            
            if self.bytesRead >= self.header.length
                self.recvDone = true;
                self.recvMessage = typecast(self.recvMessage,'uint32');
            end
            
        end
    end
   
    
end
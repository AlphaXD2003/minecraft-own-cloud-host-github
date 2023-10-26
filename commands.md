### Setup
chmod u+x start_server.sh

### To run the server 
./start_server.sh

# ngrok
[Create Account on ngrok.com](https://dashboard.ngrok.com/get-started/your-authtoken)

### To invite friends
bash : ./ngrok authtoken 'your_auth_token'
bash : ./ngrok tcp -region='your_region' 'server_port'

### Here are some common region codes you can use:
us: United States
eu: Europe
ap: Asia-Pacific
au: Australia
sa: South America
jp: Japan
in: India

### Alter config.
Go to server.properties file and change according to you.
Not to allow players having cracked minecraft to play in your server :  set online-mode = true.
Change motd as your need.
You can alter pvp .


#Credit goes to 
[How2MC YouTube Channel](https://www.youtube.com/channel/UCZSZBeR-JM2u8nFhcuvMPjA)


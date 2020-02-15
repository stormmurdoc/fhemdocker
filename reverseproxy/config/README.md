# Create self-signed certificate

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout localhost.key -out localhost.crt -config localhost.conf

# Creat user for htaccess file

__Default credentials:__

Username: admin
Password: admin

         sh -c "echo -n 'maxmustermann:' >> ./.htpasswd"
         sh -c "openssl passwd -apr1 >> ./.htpasswd"


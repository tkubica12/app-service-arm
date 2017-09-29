# Deploying web site on App Service with ARM

## Prepare Resource Group
```
az group create -n appservicearm -l westeurope
```

## Deploy service plan + one site (web01)
```
az group deployment create --resource-group appservicearm --template-file web1.json --parameters @web1.parameters.json --mode Complete
```

## Add custom domain (web02)
Make sure you have CNAME configured in your DNS solution for your custom domain pointing to site URL such as tomasweb01.azurewebsites.net.

```
az group deployment create --resource-group appservicearm --template-file web2.json --parameters @web2.parameters.json --mode Complete
```

## Add certificate (web03)
Make sure you have pfx file (custom certificate) available (you can generate one with Let's encrypt CA). Prefered way to deal with secrets like certificate is to use Azure Key Vault. At this point let's use certificate directly for simplicity. Input parameters file need to contain your pbc file encoded to base64. In Linux you can this string easily this way:

```
cat cert/tomasweb01.pfx | base64 -w 0
```

Place this output to your web3.parameters.json file.

```
az group deployment create --resource-group appservicearm --template-file web3.json --parameters @web3.parameters.json --mode Complete
```

### How to generate Let's encrypt certificate (in Linux)
```
sudo apt-get update
sudo apt-get install software-properties-common -y
sudo add-apt-repository ppa:certbot/certbot
sudo apt-get update
sudo apt-get install certbot -y
sudo certbot certonly --manual --preferred-challenges dns
mkdir cert
sudo openssl pkcs12 -inkey /etc/letsencrypt/live/tomasweb01.azure.tomaskubica.cz/privkey.pem -in /etc/letsencrypt/live/tomasweb01.azure.tomaskubica.cz/fullchain.pem -export -out cert/tomasweb01.pfx
```

## Add deployment slots test and staging (web04)
```
az group deployment create --resource-group appservicearm --template-file web4.json --parameters @web4.parameters.json --mode Complete
```

## Refactor to support multiple sites (web05)
We will be deploying multiple sites from single desired state template and we need to refactor. Parameters will be provided in a way to support multiple sites and we will use copy function in ARM to create multiple instances of resources.

```
az group deployment create --resource-group appservicearm --template-file web5.json --parameters @web5.parameters.json --mode Complete
```


## Add SQL DB in elastic pool and push connection string to web site (web06)
Currently ARM does not support creating additional DB user accounts. Only user on DB server level is supported. In case of individual databases we could create individual DB server object for each site, but in out case we need to leverage elastic pools. Therefore we deploy database with master password and configure App Service with connection string with individual DB login as provided in parameters file. Actual creation of per-DB user login will be then handled by separate script outside of ARM template.

```
az group deployment create --resource-group appservicearm --template-file web6.json --parameters @web6.parameters.json --mode Complete
```

Make sure that in your template you have enabled source IP of station that will invoke user creation script on your SQL Server firewall. Then execute following PowerShell script that will use your parameters file from template to connect to each database via admin login and configure per-db users as defined in template file.

Use this to create users and give them db_owner permissions in their DB. If user already exist, script will skip it (no update of password)
```
.\configureSQL.ps1 -ParamatersFile .\web6.parameters.json
```

If you want to alter users already existing (eg. if you need to change passwords) use -UpdateUsers flag

```
.\configureSQL.ps1 -ParamatersFile .\web6.parameters.json -UpdateUsers
```

## Clean up
```
az group delete -n appservicearm -y 
```
# Create and manage cloud resources Lab


1. First we have to make a VM instance
# - Name the instace <Instance Name>
# - Use f1-micro machine type
# - Use default image type (Debian Linux)
gcloud compute instances create <Instance Name> --machine-type f1-micro --zone us-east1-b


2. Create a Kubernetes Cluster
# - Create a cluster in us-east1-b ZONE
# - Use docker container hello-app (gcr.io/google-samples/hello-app:2.0)
# - Expose the app on <App Port Number>

gcloud config set compute/zone us-east1-b
gcloud container clusters create <Instance Name>
gcloud container clusters get-credentials <Instance Name>
kubectl create deployment <Instance Name> --image=gcr.io/google-samples/hello-app:2.0
kubectl expose deployment <Instance Name> --type=LoadBalancer --port <Port>

# To inspect service
kubectl get service


3. Create a HTTP Load Balancer
# - Needs to be an NGINX web servers
# - Custom shell startup script

# Create a startup script
cat << EOF > startup.sh
#! /bin/bash
apt-get update
apt-get install -y nginx
sed -i -- 's/nginx/Google Cloud Platform - '"\$HOSTNAME"'/' /var/www/html/index.nginx-debian.html
service nginx start
EOF

# Create a template for NGINX
gcloud compute instance-templates create nginx-template \
   --region=us-east1 \
   --metadata=startup-script=startup.sh \
   --network nucleus-vpc \
   --machine-type g1-small 


# Create a pool
gcloud compute target-pools create nginx-pool

# Create managed instance group from template that becomes part of target pool
gcloud compute instance-groups managed create nginx-group \
    --base-instance-name nginx \
    --template=nginx-template \
    --size=2 \
    --target-pool=nginx-pool\
    --zone=us-east1-b

# Create firewall rule <Firewall Rule>
gcloud compute firewall-rules create <Firewall Rule> \
    --allow tcp:80 \
    --network nucleus-vpc

# Create forwarding rules for nginx backend to pool
gcloud compute forwarding-rules create nginx-lb \
    --region us-east1 \
    --ports=80 \
    --target-pool nginx-pool

# Create a health check for the load balancer
gcloud compute health-checks create http http-basic-check \
    --port 80

# Add the port name required
gcloud compute instance-groups managed set-named-ports nginx-group \
    --named-ports http:80

# Create a backend service
gcloud compute backend-services create nginx-backend \
    --protocol=HTTP \
    --health-checks=http-basic-check \
    --global

# Add your instace group as the backend to the backend service
gcloud compute backend-services add-backend nginx-backend \
    --instance-group=nginx-group \
    --instance-group-zone=us-east1-b \
    --global

# Create a URL Map
gcloud compute url-maps create web-map \
    --default-service nginx-backend

# Create a target HTTP Proxy to route requests to URL Map
gcloud compute target-http-proxies create http-lb-proxy \
    --url-map web-map

# Create a global forwarding rule to route incoming requests to proxy
gcloud compute forwarding-rules create http-content-rule \
    --global \
    --target-http-proxy=http-lb-proxy \
    --ports=80

gcloud compute forwarding-rules list
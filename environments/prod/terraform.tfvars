project_name = "mywebapp"
location     = "japaneast"
suffix       = "prd001"

entra_tenant_id = "<YOUR_TENANT_ID>"

vnet_address_space        = "10.2.0.0/16"
subnet_app_service_prefix = "10.2.1.0/24"
subnet_postgresql_prefix  = "10.2.2.0/24"

app_service_sku   = "P1v3"
docker_image_name = "nginx:latest"
docker_registry_url = "https://index.docker.io"

db_admin_login = "pgadmin"
db_name        = "appdb"
postgresql_sku = "GP_Standard_D2s_v3"

# 機密情報は環境変数で指定してください
# export TF_VAR_db_password="your-secret-password"
# export TF_VAR_docker_registry_username="your-username"
# export TF_VAR_docker_registry_password="your-password"

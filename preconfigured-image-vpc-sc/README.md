
## Usage
1. Clone repo
```
git clone https://github.com/jbrache/cloud-workstations-preconfigured.git

```

2. Rename and update required variables in terraform.tvfars.template
```
mv terraform.tfvars.template terraform.tfvars
#Update required variables
```
3. Execute Terraform commands with existing identity (human or service account) to build Cloud Workstations Infrastructure 

```
cd ~/cloud-workstations-preconfigured/
terraform init
terraform plan
terraform apply
```

### Further Information and Links
* [How to access GCP Cloud Workstation with private gateway?](https://medium.com/@derek10cloud/how-to-access-gcp-cloud-workstation-with-private-gateway-5b0f9aee799c)
* [My Cloud Workstation productivity setup](https://medium.com/google-cloud/my-cloud-workstation-productivity-setup-c11ab5f35c0d)
* Official Cloud Workstation documentation on how to [customize the workstation image](https://cloud.google.com/workstations/docs/customize-container-images)
* Example Github [Repository by Carlos Afonso](https://github.com/carlosafonso/cloud-workstations-custom-image) with a customized Workstation Image and TF resources
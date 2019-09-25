test:
	make clean
	summon terraform destroy -force
	summon terraform apply -auto-approve
	summon terraform plan -detailed-exitcode
	make clean

clean:
	summon terraform destroy -force -target module.instance
	summon terraform destroy -force

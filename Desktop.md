Packer + Vagrant Workshop - Desktop Virtualization
==================================================

# Objective:

* Demonstration of Packer and Vagrant on a desktop virtualization platform, specifically VirtualBox

*NB: never commit your private credentials to your source repository* 

See [Readme.md](Readme.md) for workshop prerequisites

# Setup
Vagrant requires an ssh keys pair for access to your VM. This keys need to be deployed in the image.

Create an ssh key
```
# ssh-keygen -t rsa -f workshop.key -N "" -C workshop.key
```

# Packer
This workshop builds packer from ISO on VirtualBox. Packer needs this in the workshop.json:

* `<builder>.iso_url`           - ISO location on your disk
* `<builder>.iso_checksum_type` - "None" means we are ignoring it
* `<builder>.iso_checksum`      - this value will be ignored but still needs to be present, set it to something obviously invalid
* `<builder>.ssh_username`      - the ssh username, matching the one in the kickstart file
* `<builder>.ssh_password`      - the password, matching the one in the kickstart file

The workshop.json Packer configuration implements the Vagrant box requirements, e.g.

* creating the user `vagrant`
* uploading the public key (`workshop.key.pub`)
* setting the `vagrant` user's sudo access
* installing VirtualBox Guest Additions. VirtualBox Guest Additions is required to implement shared folders and other useful Vagrant features
    * <builder>.guest_additions_url    - ISO location on your disk
    * <builder>.guest_additions_sha256 - calculate using `shasum -a 256 /path/to/VBoxGuestAdditions.iso`

## To build your Packer image:

```
# packer build --only=desktop workshop.json
```

# Vagrant
This workshop uses the user `vagrant` with the workshop.key for SSH access. Vagrant needs this in the vagrantfile:

* `config.ssh.username         = "vagrant"` - the username to access the image
* `config.ssh.private_key_path = "workshop.key" - the private key matching the public key

This workshop adds the box create by Packer to your local box catalog.

* `desktop.vm.box     = "desktop-workshop"` - the name of the box
* `desktop.vm.box_url = "packer_desktop_virtualbox.box"` - the box file to register

To see your box catalog:
```
# vagrant box list
```

To manually add the box instead, you would do this:
```
# vagrant box add --name packer-desktop-workshop packer_centos-7.0-dvd-workshop_virtualbox.box
```

*NB: you don't need to do this.*

## To launch and use your instance:

```
# vagrant up desktop
# vagrant ssh desktop
```

## To delete your instance
```
# vagrant destroy desktop
```


# Rebuilding your image
If you rebuild your image using Packer, you need to delete the box in your box catalog.
```
vagrant box remove desktop-workshop
```

When you next `vagrant up desktop`, Vagrant will take your box file `packer-desktop-virtualbox.box` and add it to your local box catalog.

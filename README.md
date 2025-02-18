# lsws1clk 
[![Build Status](https://github.com/Code-Egg/lsws1clk/workflows/lsws1clk/badge.svg)](https://github.com/Code-Egg/lsws1clk/actions)
[<img src="https://img.shields.io/badge/Made%20with-BASH-orange.svg">](https://en.wikipedia.org/wiki/Bash_(Unix_shell)) 

Description
--------
This script is design for application quick install and testing porpuse.

lsws1clk is a one-click installation script for LiteSpeed Web Server. Using this script,
you can quickly and easily install:
| LSWS+PHP+DB|Application|Cache Plugin|
| :-------------: | :-------------: | :-------------: |
| V |WordPress | V |
| V |Magento2 | V |
|V|OpenCart| |
|V|PrestaShop| |
|V|Mautic| |
|V|Drupal| V |

The script come with trial license by default which has 15 days for free. After that, you may want to apply with your license. Or you can apply your serial number with `--license xxxxxxxx`. License start from $0. [Read More](https://www.litespeedtech.com/products/litespeed-web-server/lsws-pricing)

# How to use
---------

## Install Pre-Requisites
For CentOS/RHEL Based Systems
```bash
yum install git -y; git clone https://github.com/Code-Egg/lsws1clk.git
```

For Debian/Ubuntu Based Systems
```bash
apt install git -y; git clone https://github.com/Code-Egg/lsws1clk.git
```

## Install
### Pure LSWS 
``` bash
lsws1clk/lsws1clk.sh --pure
```
### Specified serial number 
``` bash
lsws1clk/lsws1clk.sh -L xxxxxxxxxxxxx
```
### WordPress
``` bash
lsws1clk/lsws1clk.sh -W
```
### Magento
``` bash
lsws1clk/lsws1clk.sh -M
```
### Magento + Sample data
``` bash
lsws1clk/lsws1clk.sh -M -S
```
### OpenCart
``` bash
lsws1clk/lsws1clk.sh -O
```
### PrestaShop
``` bash
lsws1clk/lsws1clk.sh -P
```
### Mautic
``` bash
lsws1clk/lsws1clk.sh --mautic
```

### Drupal
``` bash
lsws1clk/lsws1clk.sh --drupal
```

## Uninstall
### Uninstall LSWS and LSPHP
``` bash
lsws1clk/lsws1clk.sh --uninstall
```
### Uninstall LSWS, LSPHP, all packages and document
``` bash
lsws1clk/lsws1clk.sh --uninstall-all
```

## Benchmark
* Test client: 
online tool - [load.io](https://loader.io/) with 5000 clients 

* Test Server:
[DigitalOcean](https://www.digitalocean.com/) $5 plan server

* Target:
WordPress v5.3 main page 

* Result:
5000 request per seconds without any error

![](/img/loader-2.png)

![](/img/loader-3.png)

# Problems/Suggestions/Feedback/Contribution
Please raise an issue on the repository, or send a PR for contributing. 


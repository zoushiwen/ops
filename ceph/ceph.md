### 1. 服务端创建存储池pool
> rados mkpool sata_pool1

### 2.服务端 rbd 创建块设备
  > 服务端执行命令 rbd create <pool-name>/<image-name> --size 200G
  - --size后接rbd块设备的大小，单位MB
  - --pool后接该rbd块设备所在存储池名称
~~~
## 在 sata_pool1创建 zjt_test_image
[root@ceph01 /etc/ceph]  rbd -p sata_pool1 create zjt_test_image --size 128

## 查看 rbd 块设备信息
[root@ceph01 /etc/ceph]# rbd -p sata_pool1 info zjt_test_image
rbd image 'zjt_test_image':
	size 128 MB in 32 objects
	order 22 (4096 kB objects)
	block_name_prefix: rb.0.54100a.6b8b4567
	format: 1

~~~
### 3.安装ceph客户端
~~~
[root@q12469v ~]# yum install ceph
~~~

### 4. 将服务端的ceph.conf 和密钥文件拷贝到ceph客户端

~~~
## 拷贝服务端配置文件
[root@ceph01 /etc/ceph]# scp ceph.conf root@q12469v.cloud.shbt.qihoo.net:/etc/ceph/
## 拷贝密钥文件在客户端
[root@ceph01 /etc/ceph]# scp ceph.client.admin.keyring root@q12469v.cloud.shbt.qihoo.net:/etc/ceph/
~~~

### 5. 客户端挂载rbd并使用
- 映射rbd到客户端并挂载使用
~~~
## 映射 rbd 块设备
[root@q12469v ~]# rbd map sata_pool1/zjt_test_image
## 查看磁盘
[root@q12469v ~]# fdisk -l
~~~
- 格式化裸设备/dev/rbd0，创建ext4文件系统，并挂载磁盘到/mnt 目录下
~~~
[root@q12469v ~]# mkfs.ext4 /dev/rbd0
## 挂载磁盘到 /mnt 
[root@q12469v ~]#mount /dev/rbd0 /mnt/
~~~
这样，我们就可以使用rbd块设备了


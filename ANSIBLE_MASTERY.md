# 🚀 Ansible Mastery Guide
> A comprehensive, hands-on reference for learning Ansible from fundamentals to advanced orchestration.

---

## 📚 Table of Contents

1. [Introduction to Ansible](#1-introduction-to-ansible)
2. [Installation & Environment Setup](#2-installation--environment-setup)
3. [Ansible Architecture & Core Components](#3-ansible-architecture--core-components)
4. [Inventory Management](#4-inventory-management)
5. [Ad-hoc Commands](#5-ad-hoc-commands)
6. [Playbooks](#6-playbooks)
7. [Variables & Facts](#7-variables--facts)
8. [Conditionals & Loops](#8-conditionals--loops)
9. [Handlers](#9-handlers)
10. [Roles](#10-roles)
11. [Jinja2 Templates](#11-jinja2-templates)
12. [Modules Deep Dive](#12-modules-deep-dive)
13. [Ansible Vault (Secrets Management)](#13-ansible-vault-secrets-management)
14. [Error Handling & Debugging](#14-error-handling--debugging)
15. [Dynamic Inventory](#15-dynamic-inventory)
16. [Ansible Galaxy](#16-ansible-galaxy)
17. [Tags & Selective Execution](#17-tags--selective-execution)
18. [Delegation, Local Actions & Lookups](#18-delegation-local-actions--lookups)
19. [Callback Plugins & Custom Plugins](#19-callback-plugins--custom-plugins)
20. [CI/CD Integration with Ansible](#20-cicd-integration-with-ansible)
21. [Performance Tuning & Optimization](#21-performance-tuning--optimization)
22. [Ansible in Kubernetes & Container Environments](#22-ansible-in-kubernetes--container-environments)
23. [Best Practices & Anti-Patterns](#23-best-practices--anti-patterns)
24. [Summary & Further Learning](#24-summary--further-learning)

---

## 1. Introduction to Ansible

### What is Ansible?

Ansible is an open-source **IT automation engine** developed by Red Hat. It automates:
- **Configuration Management** — Ensure servers are in a desired state
- **Application Deployment** — Deploy apps consistently across environments
- **Orchestration** — Coordinate multi-tier deployments
- **Infrastructure Provisioning** — Spin up cloud resources

### Why Ansible?

| Feature | Description |
|---|---|
| **Agentless** | No agent required on managed nodes — uses SSH/WinRM |
| **Idempotent** | Running a playbook multiple times produces the same result |
| **Human-readable** | YAML-based; easy to read and write |
| **Batteries included** | 3000+ built-in modules covering cloud, OS, network |
| **Push-based** | Control node pushes config to managed nodes |

### Ansible vs Alternatives

| Tool | Model | Language | Agent? |
|---|---|---|---|
| Ansible | Push | YAML | No |
| Puppet | Pull | Ruby DSL | Yes |
| Chef | Pull | Ruby | Yes |
| SaltStack | Push/Pull | YAML/Python | Optional |

---

## 2. Installation & Environment Setup

### Prerequisites

- Python 3.9+ on the **control node**
- SSH access to managed nodes
- `sshpass` (optional, for password-based SSH)

### Install Ansible

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# RHEL/CentOS/Rocky Linux
sudo dnf install -y epel-release
sudo dnf install -y ansible

# pip (universal, recommended for latest version)
pip3 install ansible

# Verify installation
ansible --version
```

### SSH Key Setup (Passwordless Authentication)

```bash
# Generate SSH key pair on control node
ssh-keygen -t ed25519 -C "ansible-controller" -f ~/.ssh/ansible_key

# Copy public key to all managed nodes
ssh-copy-id -i ~/.ssh/ansible_key.pub user@192.168.1.10
ssh-copy-id -i ~/.ssh/ansible_key.pub user@192.168.1.11

# Test connectivity
ssh -i ~/.ssh/ansible_key user@192.168.1.10 "echo Connected"
```

### Directory Structure (Recommended Project Layout)

```
my-ansible-project/
├── ansible.cfg               # Project-level config (overrides global)
├── inventory/
│   ├── hosts                 # Static inventory
│   ├── group_vars/
│   │   ├── all.yml           # Variables for all groups
│   │   ├── webservers.yml
│   │   └── dbservers.yml
│   └── host_vars/
│       ├── web01.yml
│       └── db01.yml
├── playbooks/
│   ├── site.yml              # Master playbook
│   ├── webservers.yml
│   └── dbservers.yml
├── roles/
│   ├── nginx/
│   ├── mysql/
│   └── common/
├── files/                    # Static files to copy
├── templates/                # Jinja2 templates
└── vault/                    # Encrypted secrets
    └── secrets.yml
```

### ansible.cfg Configuration

```ini
# ansible.cfg
[defaults]
inventory          = ./inventory/hosts
remote_user        = ubuntu
private_key_file   = ~/.ssh/ansible_key
host_key_checking  = False
forks              = 20
retry_files_enabled = False
stdout_callback    = yaml
callback_whitelist = profile_tasks, timer
log_path           = ./ansible.log

[privilege_escalation]
become             = True
become_method      = sudo
become_user        = root
become_ask_pass    = False

[ssh_connection]
ssh_args           = -o ControlMaster=auto -o ControlPersist=60s
pipelining         = True
```

---

## 3. Ansible Architecture & Core Components

```
┌─────────────────────────────────────────────────┐
│               CONTROL NODE                      │
│                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │
│  │Inventory │  │Playbooks │  │  ansible.cfg │  │
│  └──────────┘  └──────────┘  └──────────────┘  │
│                     │                           │
│              ┌──────▼──────┐                    │
│              │  Ansible    │                    │
│              │  Engine     │                    │
│              └──────┬──────┘                    │
└─────────────────────┼───────────────────────────┘
                      │ SSH / WinRM
          ┌───────────┼────────────┐
          ▼           ▼            ▼
    ┌──────────┐ ┌──────────┐ ┌──────────┐
    │  web01   │ │  web02   │ │   db01   │
    │(Ubuntu)  │ │(Ubuntu)  │ │(CentOS)  │
    └──────────┘ └──────────┘ └──────────┘
          MANAGED NODES (No Agent Required)
```

### Core Components

| Component | Description |
|---|---|
| **Control Node** | Machine where Ansible is installed and commands run from |
| **Managed Node** | Target server(s) Ansible configures |
| **Inventory** | File/script listing managed nodes and groups |
| **Playbook** | YAML file defining automation tasks |
| **Play** | A set of tasks mapped to a group of hosts |
| **Task** | A single action calling an Ansible module |
| **Module** | Reusable unit of work (e.g., `apt`, `copy`, `service`) |
| **Role** | Reusable, self-contained collection of tasks/vars/templates |
| **Handler** | Task triggered by a `notify` directive |
| **Fact** | System information gathered from managed nodes |
| **Variable** | Named value used to parameterize playbooks |
| **Template** | Jinja2 file rendered with variables before deployment |
| **Vault** | Encrypted storage for sensitive data |
| **Galaxy** | Community hub for sharing roles and collections |

---

## 4. Inventory Management

### Static Inventory (INI Format)

```ini
# inventory/hosts

# Ungrouped hosts
192.168.1.5

[webservers]
web01 ansible_host=192.168.1.10 ansible_user=ubuntu
web02 ansible_host=192.168.1.11 ansible_user=ubuntu

[dbservers]
db01 ansible_host=192.168.1.20 ansible_user=centos ansible_port=2222
db02 ansible_host=192.168.1.21

[loadbalancers]
lb01 ansible_host=192.168.1.30

# Group of groups (children)
[production:children]
webservers
dbservers
loadbalancers

# Group variables
[webservers:vars]
http_port=80
max_clients=200

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

### Static Inventory (YAML Format)

```yaml
# inventory/hosts.yml
all:
  vars:
    ansible_python_interpreter: /usr/bin/python3
  children:
    webservers:
      vars:
        http_port: 80
        app_env: production
      hosts:
        web01:
          ansible_host: 192.168.1.10
          ansible_user: ubuntu
        web02:
          ansible_host: 192.168.1.11
          ansible_user: ubuntu
    dbservers:
      hosts:
        db01:
          ansible_host: 192.168.1.20
          ansible_user: centos
        db02:
          ansible_host: 192.168.1.21
    production:
      children:
        webservers:
        dbservers:
```

### Inventory Variables (group_vars / host_vars)

```yaml
# inventory/group_vars/all.yml
ansible_user: ubuntu
ansible_ssh_private_key_file: ~/.ssh/ansible_key
ntp_servers:
  - 0.pool.ntp.org
  - 1.pool.ntp.org
timezone: Asia/Kolkata

# inventory/group_vars/webservers.yml
nginx_version: "1.24"
app_port: 8080
ssl_enabled: true

# inventory/host_vars/web01.yml
server_role: primary
nginx_worker_processes: 4
```

### Inventory Management Commands

```bash
# List all hosts
ansible-inventory --list

# Pretty-print inventory as YAML
ansible-inventory --list -y

# Show specific host variables
ansible-inventory --host web01

# Show inventory graph (group hierarchy)
ansible-inventory --graph

# Test connectivity to all hosts
ansible all -m ping

# Test specific group
ansible webservers -m ping

# List hosts matching a pattern
ansible 'webservers:!web02' --list-hosts
```

### Inventory Patterns

```bash
# All hosts
ansible all -m ping

# Specific group
ansible webservers -m ping

# Union (both groups)
ansible 'webservers:dbservers' -m ping

# Intersection (hosts in BOTH groups)
ansible 'webservers:&production' -m ping

# Exclude from group
ansible 'webservers:!web02' -m ping

# Wildcard
ansible 'web*' -m ping

# Regex pattern
ansible '~web[0-9]+' -m ping

# Range
ansible 'web[01:05]' -m ping
```

---

## 5. Ad-hoc Commands

Ad-hoc commands are one-liners for quick, non-repeatable tasks. Syntax: `ansible <pattern> -m <module> -a "<arguments>"`

### Common Ad-hoc Examples

```bash
# Ping all hosts
ansible all -m ping

# Run shell command
ansible webservers -m shell -a "uptime"
ansible webservers -m command -a "df -h"

# Copy a file
ansible webservers -m copy -a "src=/etc/hosts dest=/tmp/hosts"

# Fetch a file from remote
ansible web01 -m fetch -a "src=/var/log/nginx/error.log dest=./logs/ flat=yes"

# Install a package
ansible webservers -m apt -a "name=nginx state=present update_cache=yes" --become

# Remove a package
ansible webservers -m apt -a "name=nginx state=absent" --become

# Start a service
ansible webservers -m service -a "name=nginx state=started enabled=yes" --become

# Create a user
ansible all -m user -a "name=deploy uid=1050 shell=/bin/bash" --become

# Create a directory
ansible all -m file -a "path=/opt/app state=directory mode=0755 owner=deploy" --become

# Check disk usage
ansible all -m shell -a "df -h / | tail -1 | awk '{print \$5}'"

# Gather facts
ansible web01 -m setup
ansible web01 -m setup -a "filter=ansible_distribution*"

# Run with sudo
ansible webservers -m apt -a "name=git state=present" --become --become-user=root

# Run with different user and key
ansible webservers -m ping -u centos --private-key=~/.ssh/centos_key

# Limit parallelism (forks)
ansible all -m ping -f 5
```

---

## 6. Playbooks

### Playbook Structure

```yaml
# playbooks/site.yml
---
- name: Configure Web Servers          # Play name
  hosts: webservers                    # Target group
  become: yes                          # Privilege escalation
  gather_facts: yes                    # Collect system facts (default: yes)
  serial: 2                            # Run 2 hosts at a time (rolling update)
  max_fail_percentage: 30              # Fail play if >30% hosts fail

  vars:                                # Play-level variables
    http_port: 80
    app_name: myapp

  pre_tasks:                           # Run before roles
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

  roles:                               # Include roles
    - common
    - nginx

  tasks:                               # Task list
    - name: Ensure nginx is installed
      apt:
        name: nginx
        state: present

    - name: Deploy nginx config
      template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
        owner: root
        group: root
        mode: '0644'
      notify: Restart nginx            # Trigger handler

    - name: Ensure nginx is running
      service:
        name: nginx
        state: started
        enabled: yes

  post_tasks:                          # Run after roles
    - name: Verify nginx is serving
      uri:
        url: "http://{{ ansible_host }}"
        status_code: 200

  handlers:                            # Triggered by notify
    - name: Restart nginx
      service:
        name: nginx
        state: restarted
```

### Multi-Play Playbook

```yaml
---
# Play 1: Common setup on all hosts
- name: Common configuration
  hosts: all
  become: yes
  tasks:
    - name: Install common packages
      package:
        name:
          - vim
          - curl
          - wget
          - git
        state: present

    - name: Set timezone
      timezone:
        name: "{{ timezone | default('UTC') }}"

# Play 2: Configure web servers
- name: Setup web servers
  hosts: webservers
  become: yes
  roles:
    - nginx
    - app_deploy

# Play 3: Configure database servers
- name: Setup database servers
  hosts: dbservers
  become: yes
  roles:
    - mysql
    - mysql_backup
```

### Running Playbooks

```bash
# Basic run
ansible-playbook playbooks/site.yml

# With inventory file
ansible-playbook -i inventory/hosts playbooks/site.yml

# Dry run (check mode)
ansible-playbook playbooks/site.yml --check

# Check mode with diff (show file changes)
ansible-playbook playbooks/site.yml --check --diff

# Limit to specific hosts or groups
ansible-playbook playbooks/site.yml --limit web01
ansible-playbook playbooks/site.yml --limit 'webservers:!web02'

# Run specific tags
ansible-playbook playbooks/site.yml --tags "install,configure"

# Skip specific tags
ansible-playbook playbooks/site.yml --skip-tags "restart"

# Extra variables (override playbook vars)
ansible-playbook playbooks/site.yml -e "http_port=8080 app_env=staging"
ansible-playbook playbooks/site.yml -e @vars/extra.yml

# Start at a specific task
ansible-playbook playbooks/site.yml --start-at-task="Deploy nginx config"

# Step through tasks interactively
ansible-playbook playbooks/site.yml --step

# Verbose output
ansible-playbook playbooks/site.yml -v    # Task results
ansible-playbook playbooks/site.yml -vv   # + Connection info
ansible-playbook playbooks/site.yml -vvv  # + Full SSH debug
```

---

## 7. Variables & Facts

### Variable Precedence (Lowest → Highest)

```
1.  command line values (e.g., -e "user=foo")   ← HIGHEST
2.  role defaults (role/defaults/main.yml)
3.  inventory file/script group vars
4.  inventory group_vars/all
5.  playbook group_vars/all
6.  inventory group_vars/*
7.  playbook group_vars/*
8.  inventory host_vars/*
9.  playbook host_vars/*
10. host facts / cached set_facts
11. play vars
12. play vars_prompt
13. play vars_files
14. role vars (role/vars/main.yml)
15. block vars (in block section)
16. task vars (only for that task)
17. include_vars
18. set_facts / registered vars
19. role (and include_role) params
20. include params
21. extra vars (-e)                              ← LOWEST
```

### Defining Variables

```yaml
# Play-level vars
- name: Example
  hosts: all
  vars:
    app_name: myapp
    app_port: 8080
    app_config:
      max_connections: 100
      timeout: 30
    supported_distros:
      - Ubuntu
      - Debian
      - CentOS

# vars_files (external YAML file)
  vars_files:
    - vars/common.yml
    - vars/{{ app_env }}.yml    # Dynamic file based on variable

# Prompting user for input
  vars_prompt:
    - name: db_password
      prompt: "Enter database password"
      private: yes              # Hides input (like a password field)
      confirm: yes
```

### Registering Variables

```yaml
- name: Check if file exists
  stat:
    path: /etc/nginx/nginx.conf
  register: nginx_conf_stat

- name: Show file info
  debug:
    msg: "File exists: {{ nginx_conf_stat.stat.exists }}"

- name: Get current date
  command: date +%Y-%m-%d
  register: current_date

- name: Use registered variable
  debug:
    msg: "Today is {{ current_date.stdout }}"

- name: Capture service status
  command: systemctl is-active nginx
  register: nginx_status
  ignore_errors: yes

- name: Show nginx status
  debug:
    msg: "Nginx is {{ nginx_status.stdout }}"
```

### set_fact — Runtime Variables

```yaml
- name: Set a fact dynamically
  set_fact:
    app_version: "2.5.1"
    deploy_timestamp: "{{ ansible_date_time.iso8601 }}"
    is_primary: "{{ inventory_hostname == 'web01' }}"
    cacheable: yes    # Persist fact across plays in same run
```

### Ansible Facts

```yaml
# Auto-gathered facts (gather_facts: yes)
- name: Show OS details
  debug:
    msg: >
      Host: {{ inventory_hostname }}
      OS: {{ ansible_distribution }} {{ ansible_distribution_version }}
      Kernel: {{ ansible_kernel }}
      Arch: {{ ansible_architecture }}
      IP: {{ ansible_default_ipv4.address }}
      Memory: {{ ansible_memtotal_mb }} MB
      CPUs: {{ ansible_processor_vcpus }}
      Hostname: {{ ansible_hostname }}

# Custom facts (stored in /etc/ansible/facts.d/*.fact on the managed node)
# File: /etc/ansible/facts.d/app.fact (INI format)
# [app]
# version=2.5.1
# environment=production
# Access via: {{ ansible_local.app.app.version }}

# Gathering specific facts
- name: Gather only network facts
  setup:
    gather_subset:
      - network
      - virtual

# Disable fact gathering for speed
- name: Fast play (no facts needed)
  hosts: all
  gather_facts: no
  tasks:
    - name: Ping
      ping:
```

### Variable Filters (Jinja2)

```yaml
- name: Variable filter examples
  debug:
    msg: "{{ item }}"
  loop:
    # String operations
    - "{{ 'hello world' | upper }}"             # HELLO WORLD
    - "{{ 'Hello World' | lower }}"             # hello world
    - "{{ '  hello  ' | trim }}"               # hello
    - "{{ 'hello' | replace('l','r') }}"        # herro
    - "{{ app_name | default('myapp') }}"       # fallback if undefined
    - "{{ some_var | default(omit) }}"          # omit the arg if undefined

    # Number operations
    - "{{ '42' | int }}"                        # integer conversion
    - "{{ 3.14159 | round(2) }}"               # 3.14
    - "{{ [1,5,3] | max }}"                     # 5
    - "{{ [1,5,3] | min }}"                     # 1

    # List/dict operations
    - "{{ [1,2,3,4,5] | length }}"             # 5
    - "{{ [3,1,2] | sort }}"                   # [1, 2, 3]
    - "{{ ['a','b','c'] | join(', ') }}"       # a, b, c
    - "{{ [1,2,2,3] | unique }}"               # [1, 2, 3]
    - "{{ {'a':1,'b':2} | dict2items }}"       # list of key/value dicts

    # Type tests
    - "{{ some_var is defined }}"
    - "{{ some_var is undefined }}"
    - "{{ 42 is number }}"
    - "{{ 'hello' is string }}"
    - "{{ [] is iterable }}"

    # JSON/YAML
    - "{{ my_dict | to_json }}"
    - "{{ my_dict | to_nice_json }}"
    - "{{ my_dict | to_yaml }}"
    - "{{ json_string | from_json }}"
```

---

## 8. Conditionals & Loops

### Conditionals (when)

```yaml
# Simple condition
- name: Install apache on Debian
  apt:
    name: apache2
    state: present
  when: ansible_os_family == "Debian"

# Multiple conditions (AND)
- name: Install on Ubuntu 22.04 only
  apt:
    name: nginx
    state: present
  when:
    - ansible_distribution == "Ubuntu"
    - ansible_distribution_version == "22.04"

# OR condition
- name: Install on Debian or Ubuntu
  apt:
    name: nginx
    state: present
  when: ansible_distribution == "Debian" or ansible_distribution == "Ubuntu"

# Using registered variable
- name: Check if service exists
  stat:
    path: /etc/systemd/system/myapp.service
  register: service_file

- name: Start service only if it exists
  service:
    name: myapp
    state: started
  when: service_file.stat.exists

# Using defined/undefined
- name: Configure proxy if variable is set
  template:
    src: proxy.conf.j2
    dest: /etc/nginx/proxy.conf
  when: proxy_host is defined

# Condition on list membership
- name: Run on specific hosts
  debug:
    msg: "I am a primary server"
  when: inventory_hostname in groups['primary']

# Negation
- name: Skip on production
  debug:
    msg: "Running debug task"
  when: app_env != "production"

# String contains
- name: Check kernel version
  debug:
    msg: "Running on newer kernel"
  when: "'5.' in ansible_kernel"
```

### Loops

```yaml
# Simple loop (with_items → loop)
- name: Install multiple packages
  apt:
    name: "{{ item }}"
    state: present
  loop:
    - nginx
    - git
    - curl
    - vim

# Loop with dict items
- name: Create users
  user:
    name: "{{ item.name }}"
    uid: "{{ item.uid }}"
    shell: "{{ item.shell | default('/bin/bash') }}"
    groups: "{{ item.groups | default([]) }}"
  loop:
    - { name: deploy, uid: 1050, groups: ['sudo'] }
    - { name: app,    uid: 1051, shell: /sbin/nologin }
    - { name: backup, uid: 1052 }

# Loop with index
- name: Show item index
  debug:
    msg: "Item {{ ansible_loop.index }}: {{ item }}"
  loop:
    - alpha
    - beta
    - gamma
  loop_control:
    label: "{{ item }}"       # Control what's shown in output
    index_var: my_idx         # Custom index variable name
    loop_var: my_item         # Rename 'item' to avoid nested loop conflicts

# Loop with range
- name: Create numbered directories
  file:
    path: "/opt/worker-{{ item }}"
    state: directory
  loop: "{{ range(1, 6) | list }}"   # 1 to 5

# dict2items — loop over dictionary
- name: Set environment variables
  lineinfile:
    path: /etc/environment
    line: "{{ item.key }}={{ item.value }}"
  loop: "{{ env_vars | dict2items }}"
  vars:
    env_vars:
      APP_ENV: production
      DB_HOST: db01
      LOG_LEVEL: info

# Nested loops (with subelements)
- name: Assign SSH keys to users
  authorized_key:
    user: "{{ item.0.name }}"
    key: "{{ item.1 }}"
  with_subelements:
    - "{{ users }}"
    - ssh_keys
  vars:
    users:
      - name: alice
        ssh_keys:
          - "ssh-rsa AAAA...alice_key1"
          - "ssh-rsa BBBB...alice_key2"
      - name: bob
        ssh_keys:
          - "ssh-rsa CCCC...bob_key1"

# until loop (retry until condition met)
- name: Wait for app to start
  uri:
    url: "http://localhost:8080/health"
    status_code: 200
  register: health_check
  until: health_check.status == 200
  retries: 10
  delay: 5                    # Seconds between retries
```

### Blocks (Grouping Tasks)

```yaml
- name: Install and configure nginx
  block:
    - name: Install nginx
      apt:
        name: nginx
        state: present

    - name: Copy config
      template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf

    - name: Start nginx
      service:
        name: nginx
        state: started

  when: ansible_os_family == "Debian"   # Applied to entire block
  become: yes
  tags: nginx

  rescue:                               # Runs if any task in block fails
    - name: Log failure
      debug:
        msg: "nginx setup failed on {{ inventory_hostname }}"

    - name: Remove broken config
      file:
        path: /etc/nginx/nginx.conf
        state: absent

  always:                               # Always runs (like finally)
    - name: Record task completion
      debug:
        msg: "nginx block finished (success or failure)"
```

---

## 9. Handlers

Handlers are tasks that **only run when notified** and run **after all tasks** in a play complete (not immediately). They run only **once** even if notified multiple times.

```yaml
---
- name: Configure nginx
  hosts: webservers
  become: yes
  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present
      notify: Start nginx            # Single handler

    - name: Deploy nginx config
      template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      notify:
        - Validate nginx config      # Multiple handlers
        - Reload nginx

    - name: Deploy SSL certificate
      copy:
        src: "{{ ssl_cert }}"
        dest: /etc/ssl/certs/
      notify: Reload nginx           # Same handler — runs only once

  handlers:
    - name: Start nginx
      service:
        name: nginx
        state: started
        enabled: yes

    - name: Validate nginx config
      command: nginx -t
      changed_when: false

    - name: Reload nginx
      service:
        name: nginx
        state: reloaded
      listen: "web server config changed"   # Alternative notification mechanism

    - name: Restart nginx
      service:
        name: nginx
        state: restarted

# Force handlers to run immediately (mid-play)
    - name: Flush handlers now
      meta: flush_handlers
```

### Global Handlers in a Separate File

```yaml
# handlers/main.yml (inside a role)
---
- name: Restart nginx
  service:
    name: nginx
    state: restarted

- name: Reload nginx
  service:
    name: nginx
    state: reloaded

- name: Reload systemd
  systemd:
    daemon_reload: yes
```

---

## 10. Roles

Roles provide a way to **package and reuse** automation content. They enforce a standard directory structure.

### Role Directory Structure

```
roles/
└── nginx/
    ├── defaults/
    │   └── main.yml          # Default variables (lowest precedence)
    ├── vars/
    │   └── main.yml          # Role variables (high precedence)
    ├── tasks/
    │   └── main.yml          # Main task list
    ├── handlers/
    │   └── main.yml          # Handlers
    ├── templates/
    │   └── nginx.conf.j2     # Jinja2 templates
    ├── files/
    │   └── index.html        # Static files
    ├── meta/
    │   └── main.yml          # Role metadata, dependencies
    ├── tests/
    │   ├── inventory         # Test inventory
    │   └── test.yml          # Test playbook
    └── README.md
```

### Creating a Role

```bash
# Auto-generate role scaffold
ansible-galaxy role init roles/nginx

# With custom path
ansible-galaxy init --init-path=./roles nginx
```

### Role: defaults/main.yml

```yaml
# roles/nginx/defaults/main.yml
nginx_version: latest
nginx_port: 80
nginx_worker_processes: auto
nginx_worker_connections: 1024
nginx_server_name: "_"
nginx_document_root: /var/www/html
nginx_ssl_enabled: false
nginx_ssl_port: 443
nginx_access_log: /var/log/nginx/access.log
nginx_error_log: /var/log/nginx/error.log
nginx_extra_params: {}
```

### Role: tasks/main.yml

```yaml
# roles/nginx/tasks/main.yml
---
- name: Include OS-specific variables
  include_vars: "{{ ansible_os_family }}.yml"

- name: Include install tasks
  include_tasks: install.yml

- name: Include configure tasks
  include_tasks: configure.yml

- name: Include ssl tasks
  include_tasks: ssl.yml
  when: nginx_ssl_enabled | bool
```

### Role: tasks/install.yml

```yaml
# roles/nginx/tasks/install.yml
---
- name: Install nginx
  package:
    name: "nginx{% if nginx_version != 'latest' %}={{ nginx_version }}{% endif %}"
    state: present
    update_cache: yes
  notify: Reload systemd

- name: Ensure nginx service directory exists
  file:
    path: /etc/nginx/conf.d
    state: directory
    mode: '0755'
```

### Role: tasks/configure.yml

```yaml
# roles/nginx/tasks/configure.yml
---
- name: Deploy main nginx config
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
    validate: /usr/sbin/nginx -t -c %s
  notify: Reload nginx

- name: Deploy default vhost config
  template:
    src: default.conf.j2
    dest: /etc/nginx/conf.d/default.conf
  notify: Reload nginx

- name: Start and enable nginx
  service:
    name: nginx
    state: started
    enabled: yes
```

### Role: meta/main.yml

```yaml
# roles/nginx/meta/main.yml
galaxy_info:
  author: Raja
  description: Install and configure Nginx web server
  company: Onward Technologies
  license: MIT
  min_ansible_version: "2.12"
  platforms:
    - name: Ubuntu
      versions:
        - "20.04"
        - "22.04"
    - name: EL
      versions:
        - "8"
        - "9"
  galaxy_tags:
    - nginx
    - web
    - linux

dependencies:
  - role: common           # This role depends on 'common' role
    vars:
      common_user: nginx
```

### Using Roles in Playbooks

```yaml
---
- name: Deploy web application
  hosts: webservers
  become: yes

  # Simple role usage
  roles:
    - common
    - nginx
    - { role: app_deploy, app_version: "1.5.0", tags: ['app'] }

  # Modern include_role (dynamic, supports conditions/loops)
  tasks:
    - name: Apply monitoring role
      include_role:
        name: prometheus
      vars:
        prometheus_port: 9090
      when: monitoring_enabled | bool

    - name: Apply role per environment
      include_role:
        name: "{{ item }}"
      loop:
        - ssl_certs
        - firewall
```

---

## 11. Jinja2 Templates

### Basic Template Syntax

```jinja2
{# This is a Jinja2 comment — not rendered in output #}

{# Variables #}
{{ variable_name }}
{{ ansible_hostname }}
{{ nginx_port | default(80) }}

{# Control structures #}
{% if ssl_enabled %}
listen 443 ssl;
{% else %}
listen 80;
{% endif %}

{% for server in upstream_servers %}
    server {{ server.host }}:{{ server.port }} weight={{ server.weight | default(1) }};
{% endfor %}

{# Whitespace control with - #}
{% for item in list -%}
{{ item }}
{%- endfor %}
```

### nginx.conf.j2 — Full Template Example

```jinja2
# /roles/nginx/templates/nginx.conf.j2
# Managed by Ansible — DO NOT EDIT MANUALLY
# Generated: {{ ansible_date_time.date }}

user www-data;
worker_processes {{ nginx_worker_processes }};
pid /run/nginx.pid;
error_log {{ nginx_error_log }} warn;

events {
    worker_connections {{ nginx_worker_connections }};
    multi_accept on;
    use epoll;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    server_tokens off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log {{ nginx_access_log }} combined;

    {% if nginx_gzip_enabled | default(true) %}
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript;
    {% endif %}

    # Upstream block
    {% if nginx_upstream_servers is defined %}
    upstream {{ app_name }}_backend {
        {% for server in nginx_upstream_servers %}
        server {{ server.host }}:{{ server.port }}{% if server.backup is defined and server.backup %} backup{% endif %};
        {% endfor %}
        keepalive 32;
    }
    {% endif %}

    server {
        {% if nginx_ssl_enabled %}
        listen {{ nginx_ssl_port }} ssl http2;
        ssl_certificate     /etc/ssl/certs/{{ app_name }}.crt;
        ssl_certificate_key /etc/ssl/private/{{ app_name }}.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        {% else %}
        listen {{ nginx_port }};
        {% endif %}

        server_name {{ nginx_server_name }};
        root {{ nginx_document_root }};

        location / {
            {% if nginx_upstream_servers is defined %}
            proxy_pass http://{{ app_name }}_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            {% else %}
            try_files $uri $uri/ =404;
            {% endif %}
        }

        # Extra parameters
        {% for key, value in nginx_extra_params.items() %}
        {{ key }} {{ value }};
        {% endfor %}
    }
}
```

### systemd Service Template

```jinja2
# /roles/app_deploy/templates/myapp.service.j2
[Unit]
Description={{ app_name }} Application Service
Documentation=https://{{ app_name }}.example.com/docs
After=network.target
{% if db_enabled | default(false) %}
After=mysql.service
Requires=mysql.service
{% endif %}

[Service]
Type=simple
User={{ app_user }}
Group={{ app_group }}
WorkingDirectory={{ app_dir }}
ExecStart={{ app_dir }}/bin/{{ app_name }} \
    --port {{ app_port }} \
    --env {{ app_env }} \
    --config {{ app_dir }}/config/app.yml
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5s
StandardOutput=journal
StandardError=journal
SyslogIdentifier={{ app_name }}

Environment=NODE_ENV={{ app_env }}
{% for key, value in app_env_vars.items() %}
Environment={{ key }}={{ value }}
{% endfor %}

[Install]
WantedBy=multi-user.target
```

### Using Templates in Tasks

```yaml
- name: Deploy nginx configuration
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
    backup: yes                     # Keep backup of previous file
    validate: /usr/sbin/nginx -t -c %s   # Validate before placing
  notify: Reload nginx
```

---

## 12. Modules Deep Dive

### File Management Modules

```yaml
# file — manage files and directories
- name: Create directory
  file:
    path: /opt/myapp
    state: directory
    owner: deploy
    group: deploy
    mode: '0755'
    recurse: yes              # Apply permissions recursively

- name: Create symlink
  file:
    src: /opt/myapp/releases/v2.5.1
    dest: /opt/myapp/current
    state: link

- name: Remove file
  file:
    path: /tmp/oldconfig.bak
    state: absent

# copy — copy files to remote
- name: Copy config file
  copy:
    src: files/app.conf
    dest: /etc/myapp/app.conf
    owner: root
    group: root
    mode: '0640'
    backup: yes

- name: Write content to file
  copy:
    content: |
      export APP_ENV=production
      export DB_HOST={{ db_host }}
    dest: /etc/profile.d/myapp.sh

# fetch — retrieve files from remote
- name: Fetch log files
  fetch:
    src: /var/log/app/error.log
    dest: ./logs/{{ inventory_hostname }}/
    flat: no

# lineinfile — manage single lines in files
- name: Set max open files in limits.conf
  lineinfile:
    path: /etc/security/limits.conf
    regexp: '^deploy\s+soft\s+nofile'
    line: 'deploy soft nofile 65536'
    state: present
    backup: yes

# blockinfile — manage blocks of text
- name: Add server block to hosts file
  blockinfile:
    path: /etc/hosts
    block: |
      192.168.1.10  web01.internal web01
      192.168.1.11  web02.internal web02
    marker: "# {mark} ANSIBLE MANAGED — webservers"

# replace — replace pattern in file
- name: Replace config value
  replace:
    path: /etc/mysql/my.cnf
    regexp: '^bind-address\s*=.*'
    replace: 'bind-address = 0.0.0.0'
    backup: yes
```

### Package & Service Modules

```yaml
# apt (Debian/Ubuntu)
- name: Install packages
  apt:
    name:
      - nginx
      - python3-pip
      - certbot
    state: present
    update_cache: yes
    cache_valid_time: 3600

- name: Upgrade all packages
  apt:
    upgrade: dist
    update_cache: yes

# yum/dnf (RHEL/CentOS)
- name: Install package on RHEL
  dnf:
    name: httpd
    state: latest

# package (OS-agnostic)
- name: Install git (any OS)
  package:
    name: git
    state: present

# pip
- name: Install Python packages
  pip:
    name:
      - flask
      - gunicorn
      - psycopg2-binary
    state: present
    executable: pip3
    extra_args: --upgrade

# service / systemd
- name: Manage service
  systemd:
    name: nginx
    state: started
    enabled: yes
    daemon_reload: yes

- name: Stop and disable service
  service:
    name: apache2
    state: stopped
    enabled: no
```

### User & Group Modules

```yaml
- name: Create application group
  group:
    name: appgroup
    gid: 2000
    state: present

- name: Create application user
  user:
    name: deploy
    uid: 2001
    group: appgroup
    groups:
      - sudo
      - docker
    append: yes               # Don't replace existing groups
    shell: /bin/bash
    home: /home/deploy
    create_home: yes
    comment: "Deployment User"
    password: "{{ vault_deploy_password | password_hash('sha512') }}"
    update_password: on_create  # Only set password on user creation

- name: Add SSH authorized key
  authorized_key:
    user: deploy
    key: "{{ lookup('file', 'files/deploy_key.pub') }}"
    state: present
    exclusive: no             # Don't remove other keys
```

### Network Modules

```yaml
# uri — make HTTP requests
- name: Check application health
  uri:
    url: "http://{{ ansible_host }}:{{ app_port }}/health"
    method: GET
    status_code: 200
    timeout: 10
    return_content: yes
  register: health_response

- name: POST to API
  uri:
    url: "https://api.example.com/deploy"
    method: POST
    headers:
      Authorization: "Bearer {{ api_token }}"
      Content-Type: application/json
    body_format: json
    body:
      version: "{{ app_version }}"
      environment: "{{ app_env }}"
    status_code: [200, 201]

# wait_for — wait for conditions
- name: Wait for port to be open
  wait_for:
    host: "{{ inventory_hostname }}"
    port: 8080
    state: started
    delay: 5
    timeout: 60

- name: Wait for file to appear
  wait_for:
    path: /var/run/myapp.pid
    state: present
    timeout: 30

# firewalld
- name: Open port in firewall
  firewalld:
    port: "{{ app_port }}/tcp"
    permanent: yes
    state: enabled
    immediate: yes
```

### Cloud Modules (AWS)

```yaml
# EC2 instance
- name: Launch EC2 instance
  amazon.aws.ec2_instance:
    name: "web-{{ app_env }}-01"
    key_name: my-keypair
    instance_type: t3.micro
    image_id: ami-0c55b159cbfafe1f0
    region: ap-south-1
    security_groups:
      - web-sg
    vpc_subnet_id: subnet-abc123
    tags:
      Environment: "{{ app_env }}"
      Role: webserver
    state: present
  register: ec2_instance

# S3 bucket
- name: Create S3 bucket
  amazon.aws.s3_bucket:
    name: "myapp-{{ app_env }}-backups"
    region: ap-south-1
    versioning: yes
    encryption: AES256
    tags:
      Environment: "{{ app_env }}"
    state: present

# Upload to S3
- name: Upload backup to S3
  amazon.aws.aws_s3:
    bucket: "myapp-{{ app_env }}-backups"
    object: "backup-{{ ansible_date_time.date }}.tar.gz"
    src: /tmp/backup.tar.gz
    mode: put
    encrypt: yes
```

---

## 13. Ansible Vault (Secrets Management)

Ansible Vault encrypts sensitive data (passwords, API keys, certificates) at rest.

### Creating Encrypted Files

```bash
# Create new encrypted file
ansible-vault create vault/secrets.yml

# Encrypt existing file
ansible-vault encrypt vars/db_passwords.yml

# Edit encrypted file (decrypts → opens editor → re-encrypts)
ansible-vault edit vault/secrets.yml

# View without editing
ansible-vault view vault/secrets.yml

# Decrypt (removes encryption — use carefully!)
ansible-vault decrypt vault/secrets.yml

# Re-encrypt with a new password
ansible-vault rekey vault/secrets.yml

# Encrypt a single string (for embedding in playbooks)
ansible-vault encrypt_string 'MySecretPass123!' --name 'db_password'
# Output:
# db_password: !vault |
#           $ANSIBLE_VAULT;1.1;AES256
#           3262...
```

### vault/secrets.yml — Example

```yaml
# vault/secrets.yml (encrypted with ansible-vault)
vault_db_password: "SuperSecureP@ss123"
vault_api_key: "sk-prod-abc123xyz789"
vault_ssl_cert: |
  -----BEGIN CERTIFICATE-----
  MIIFazCCA1OgAwIBAgI...
  -----END CERTIFICATE-----
vault_ssl_key: |
  -----BEGIN PRIVATE KEY-----
  MIIEvgIBADANBgkq...
  -----END PRIVATE KEY-----
```

### Using Vault in Playbooks

```yaml
# Best practice: prefix vault vars with 'vault_'
# and create a wrapper variable in plain vars file

# vars/main.yml (plain text)
db_password: "{{ vault_db_password }}"
api_key: "{{ vault_api_key }}"

# playbook.yml
- name: Deploy application
  hosts: all
  vars_files:
    - vars/main.yml
    - vault/secrets.yml      # Encrypted file
  tasks:
    - name: Configure DB connection
      template:
        src: db.conf.j2
        dest: /etc/myapp/db.conf

# db.conf.j2
# [database]
# host={{ db_host }}
# password={{ db_password }}   ← resolved from vault
```

### Running Playbooks with Vault

```bash
# Prompt for vault password
ansible-playbook site.yml --ask-vault-pass

# Use password file (do NOT commit this file to git!)
echo "MyVaultPassword" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass
ansible-playbook site.yml --vault-password-file ~/.ansible_vault_pass

# Set in ansible.cfg
# vault_password_file = ~/.ansible_vault_pass

# Multiple vault passwords (vault IDs)
ansible-vault create --vault-id prod@prompt secrets_prod.yml
ansible-vault create --vault-id dev@~/.dev_vault_pass secrets_dev.yml
ansible-playbook site.yml --vault-id prod@prompt --vault-id dev@~/.dev_vault_pass
```

### .gitignore for Vault Safety

```gitignore
# .gitignore
.ansible_vault_pass
*vault_pass*
*.vault.key
# Never ignore vault/*.yml — they should be committed (encrypted)
```

---

## 14. Error Handling & Debugging

### Controlling Failure Behavior

```yaml
# ignore_errors — continue even if task fails
- name: Check optional service
  command: systemctl status optional-service
  ignore_errors: yes
  register: service_check

# failed_when — custom failure condition
- name: Run database migration
  command: python manage.py migrate
  register: migration_result
  failed_when:
    - migration_result.rc != 0
    - "'No migrations to apply' not in migration_result.stdout"

# changed_when — control when task is 'changed'
- name: Get app version
  command: myapp --version
  register: app_version
  changed_when: false          # Never mark as changed

- name: Run idempotent script
  command: /opt/scripts/setup.sh
  register: setup_result
  changed_when: "'already configured' not in setup_result.stdout"

# any_errors_fatal — stop ALL hosts if one fails
- name: Critical task
  hosts: all
  any_errors_fatal: yes
  tasks:
    - name: Apply database schema
      command: mysql -u root < /tmp/schema.sql

# max_fail_percentage
- name: Rolling update
  hosts: webservers
  max_fail_percentage: 20      # Fail play if >20% hosts fail
  serial: 1
  tasks:
    - name: Upgrade app
      apt:
        name: myapp
        state: latest
```

### Debugging Techniques

```yaml
# debug module
- name: Show variable value
  debug:
    msg: "The app version is {{ app_version }}"

- name: Show complex variable
  debug:
    var: ansible_default_ipv4     # Prints as YAML
    verbosity: 2                  # Only shown with -vv

# fail module — intentional failure with message
- name: Validate environment
  fail:
    msg: "ERROR: app_env must be 'staging' or 'production', got: {{ app_env }}"
  when: app_env not in ['staging', 'production']

# assert module — validate conditions
- name: Assert required variables are set
  assert:
    that:
      - db_host is defined
      - db_host | length > 0
      - app_port | int > 1024
      - app_port | int < 65535
    fail_msg: "Required variables missing or invalid"
    success_msg: "All required variables validated successfully"

# pause — pause with message (useful for inspection)
- name: Pause before restart
  pause:
    prompt: "About to restart nginx. Press ENTER to continue or Ctrl+C to abort"
    seconds: 10                   # Auto-continue after 10s

# Debugging tips
```

```bash
# Syntax check without running
ansible-playbook site.yml --syntax-check

# List all tasks that would run
ansible-playbook site.yml --list-tasks

# List hosts that would be targeted
ansible-playbook site.yml --list-hosts

# Check mode (dry run)
ansible-playbook site.yml --check --diff

# Verbose levels
ansible-playbook site.yml -v       # Task results
ansible-playbook site.yml -vv      # Show connection details
ansible-playbook site.yml -vvv     # SSH debug
ansible-playbook site.yml -vvvv    # Full connection debug

# Debug a specific host
ANSIBLE_DEBUG=1 ansible-playbook site.yml --limit web01

# Run single task and stop
ansible-playbook site.yml --start-at-task="Deploy nginx config" --step
```

---

## 15. Dynamic Inventory

Dynamic inventories query external sources (AWS, GCP, Azure, databases, etc.) at runtime.

### AWS EC2 Dynamic Inventory

```bash
# Install boto3 and the AWS collection
pip3 install boto3 botocore
ansible-galaxy collection install amazon.aws

# Create inventory plugin config
cat > inventory/aws_ec2.yml << 'EOF'
plugin: amazon.aws.aws_ec2
regions:
  - ap-south-1
filters:
  instance-state-name: running
  tag:Environment: production
keyed_groups:
  - prefix: aws
    key: tags.Role
  - prefix: region
    key: placement.region
hostnames:
  - private-ip-address
  - dns-name
compose:
  ansible_host: private_ip_address
  ansible_user: "'ubuntu'"
EOF

# Use it
ansible-inventory -i inventory/aws_ec2.yml --list
ansible-playbook -i inventory/aws_ec2.yml site.yml
```

### Custom Dynamic Inventory Script

```python
#!/usr/bin/env python3
# inventory/custom_inventory.py
"""Custom dynamic inventory — reads from a CMDB API."""

import json
import sys
import argparse
import requests

CMDB_URL = "https://cmdb.example.com/api/servers"

def get_inventory():
    """Fetch servers from CMDB and build Ansible inventory structure."""
    try:
        response = requests.get(CMDB_URL, headers={"X-API-Key": "secret"}, timeout=10)
        servers = response.json()
    except Exception as e:
        print(f"Error fetching inventory: {e}", file=sys.stderr)
        sys.exit(1)

    inventory = {
        "_meta": {"hostvars": {}},
        "all": {"children": ["ungrouped"]},
    }

    for server in servers:
        role = server.get("role", "ungrouped")
        hostname = server["hostname"]

        # Add group
        if role not in inventory:
            inventory[role] = {"hosts": [], "vars": {}}
            inventory["all"]["children"].append(role)

        inventory[role]["hosts"].append(hostname)

        # Add host variables
        inventory["_meta"]["hostvars"][hostname] = {
            "ansible_host": server["ip_address"],
            "ansible_user": server.get("ssh_user", "ubuntu"),
            "environment": server.get("environment", "production"),
            "datacenter": server.get("datacenter"),
        }

    return inventory

def get_host(hostname):
    """Return variables for a single host."""
    inventory = get_inventory()
    return inventory["_meta"]["hostvars"].get(hostname, {})

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--host", type=str)
    args = parser.parse_args()

    if args.list:
        print(json.dumps(get_inventory(), indent=2))
    elif args.host:
        print(json.dumps(get_host(args.host), indent=2))
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
```

```bash
# Make executable
chmod +x inventory/custom_inventory.py

# Test it
./inventory/custom_inventory.py --list
./inventory/custom_inventory.py --host web01

# Use with ansible
ansible-inventory -i inventory/custom_inventory.py --list
ansible-playbook -i inventory/custom_inventory.py site.yml
```

---

## 16. Ansible Galaxy

Ansible Galaxy is the official community hub for sharing **roles** and **collections**.

### Collections vs Roles

| Feature | Role | Collection |
|---|---|---|
| Scope | Tasks + templates + vars | Roles + modules + plugins + playbooks |
| Distribution | Galaxy, Git | Galaxy, Automation Hub, Git |
| Namespace | `rolename` | `namespace.collection` |
| Install | `ansible-galaxy role install` | `ansible-galaxy collection install` |

### Installing from Galaxy

```bash
# Install a role
ansible-galaxy role install geerlingguy.nginx
ansible-galaxy role install geerlingguy.mysql

# Install specific version
ansible-galaxy role install geerlingguy.nginx,3.2.0

# Install to custom path
ansible-galaxy role install geerlingguy.nginx -p ./roles

# Install a collection
ansible-galaxy collection install community.general
ansible-galaxy collection install amazon.aws
ansible-galaxy collection install kubernetes.core

# List installed roles/collections
ansible-galaxy role list
ansible-galaxy collection list
```

### requirements.yml — Declarative Dependencies

```yaml
# requirements.yml
---
roles:
  - name: geerlingguy.nginx
    version: "3.2.0"
  - name: geerlingguy.mysql
    version: "4.3.2"
  - name: my_custom_role
    src: git+https://github.com/myorg/ansible-role-custom.git
    version: main
  - name: internal_role
    src: https://nexus.internal.com/ansible/roles/common.tar.gz

collections:
  - name: amazon.aws
    version: ">=6.0.0"
  - name: community.general
    version: "7.0.0"
  - name: kubernetes.core
    version: "2.4.0"
  - name: ansible.posix
```

```bash
# Install all requirements
ansible-galaxy install -r requirements.yml
ansible-galaxy collection install -r requirements.yml

# Install roles and collections together
ansible-galaxy role install -r requirements.yml
ansible-galaxy collection install -r requirements.yml
```

### Publishing Your Own Role

```bash
# Initialize role
ansible-galaxy role init my_role

# Add role to GitHub (naming convention: ansible-role-<name>)

# Import on Galaxy (requires GitHub account linked to Galaxy)
ansible-galaxy login
ansible-galaxy import myuser my_role

# Or use a GitHub Actions workflow to auto-import on push
```

---

## 17. Tags & Selective Execution

Tags let you run or skip specific parts of your playbooks.

```yaml
---
- name: Full server setup
  hosts: all
  become: yes
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
      tags:
        - always                  # Runs even when other tags are specified
        - update

    - name: Install base packages
      apt:
        name: "{{ base_packages }}"
        state: present
      tags:
        - install
        - packages

    - name: Configure timezone
      timezone:
        name: "{{ timezone }}"
      tags:
        - configure
        - timezone

    - name: Deploy application
      include_tasks: deploy.yml
      tags:
        - deploy
        - app

    - name: Restart services
      service:
        name: "{{ item }}"
        state: restarted
      loop: "{{ managed_services }}"
      tags:
        - restart
        - never               # Only runs when explicitly called with --tags restart

  roles:
    - role: nginx
      tags: ['nginx', 'webserver']

    - role: mysql
      tags: ['mysql', 'database']
```

```bash
# Run only tasks with specific tags
ansible-playbook site.yml --tags "install,configure"

# Run all tasks EXCEPT those tagged
ansible-playbook site.yml --skip-tags "restart"

# List all tags in a playbook
ansible-playbook site.yml --list-tags

# Run tasks tagged 'always' + 'deploy'
ansible-playbook site.yml --tags "deploy"

# Force-run tasks tagged 'never'
ansible-playbook site.yml --tags "restart"
```

---

## 18. Delegation, Local Actions & Lookups

### Task Delegation

```yaml
# Run task on a different host
- name: Remove host from load balancer before update
  uri:
    url: "http://{{ lb_host }}/api/disable"
    method: POST
    body_format: json
    body:
      host: "{{ inventory_hostname }}"
  delegate_to: "{{ lb_host }}"    # Run this task on the lb host

# Run task on control node
- name: Update local DNS record
  command: "nsupdate -k /etc/dns.key"
  delegate_to: localhost

# Facts delegation
- name: Get facts from a different host
  setup:
  delegate_to: db01
  delegate_facts: true

# Rolling update with delegation
- name: Drain connections before update
  command: haproxy -sf $(cat /var/run/haproxy.pid)
  delegate_to: "{{ groups['loadbalancers'][0] }}"
```

### Local Actions

```yaml
# Run on control node only
- name: Create local backup directory
  local_action:
    module: file
    path: "./backups/{{ ansible_date_time.date }}"
    state: directory

# Equivalent form
- name: Fetch remote config for backup
  fetch:
    src: /etc/nginx/nginx.conf
    dest: "./backups/{{ inventory_hostname }}-nginx.conf"
    flat: yes
```

### Lookups (Data from Control Node)

```yaml
# file — read a local file
- name: Deploy SSH key from file
  authorized_key:
    user: deploy
    key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"

# env — read environment variable
- name: Use CI token from environment
  uri:
    url: "https://api.example.com/deploy"
    headers:
      Authorization: "Bearer {{ lookup('env', 'CI_TOKEN') }}"

# template — render a local template
- name: Get rendered config content
  debug:
    msg: "{{ lookup('template', 'templates/app.conf.j2') }}"

# pipe — run local command and capture output
- name: Get current git commit
  debug:
    msg: "Deploying commit: {{ lookup('pipe', 'git rev-parse --short HEAD') }}"

# password — generate/retrieve a password
- name: Generate MySQL root password
  debug:
    msg: "{{ lookup('password', '/tmp/mysql_root_pass length=20 chars=ascii_letters,digits') }}"

# url — fetch from URL
- name: Get latest release info from GitHub
  debug:
    msg: "{{ lookup('url', 'https://api.github.com/repos/nginx/nginx/releases/latest') | from_json | json_query('tag_name') }}"

# vars — look up variable
- name: Print a variable by constructed name
  debug:
    msg: "{{ lookup('vars', 'app_' + env_name + '_config') }}"

# dict — iterate over dictionary
- name: Show dict contents
  debug:
    msg: "Key: {{ item.key }}, Value: {{ item.value }}"
  loop: "{{ lookup('dict', my_dictionary) }}"
```

---

## 19. Callback Plugins & Custom Plugins

### Built-in Callbacks

```ini
# ansible.cfg
[defaults]
stdout_callback = yaml          # yaml, json, minimal, dense, oneline
callback_whitelist = profile_tasks, timer, log_plays

[callback_profile_tasks]
task_output_limit = 20
sort_order = descending
```

### Custom Callback Plugin

```python
# callback_plugins/deployment_notify.py
"""Send Slack notification on playbook completion."""

from ansible.plugins.callback import CallbackBase
import requests
import os

DOCUMENTATION = """
callback: deployment_notify
type: notification
short_description: Send Slack notification on playbook run
"""

class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "notification"
    CALLBACK_NAME = "deployment_notify"
    CALLBACK_NEEDS_WHITELIST = True

    def __init__(self):
        super().__init__()
        self.webhook_url = os.environ.get("SLACK_WEBHOOK_URL", "")
        self.playbook_name = ""

    def v2_playbook_on_start(self, playbook):
        self.playbook_name = playbook._file_name

    def v2_playbook_on_stats(self, stats):
        """Called at end of playbook — send final Slack summary."""
        hosts = sorted(stats.processed.keys())
        summary = []
        status = "✅ SUCCESS"

        for host in hosts:
            s = stats.summarize(host)
            summary.append(
                f"*{host}*: ok={s['ok']} changed={s['changed']} "
                f"unreachable={s['unreachable']} failed={s['failures']}"
            )
            if s["failures"] > 0 or s["unreachable"] > 0:
                status = "❌ FAILED"

        message = {
            "text": f"{status} — Ansible Playbook: `{self.playbook_name}`",
            "attachments": [{"text": "\n".join(summary), "color": "#36a64f"}]
        }

        if self.webhook_url:
            try:
                requests.post(self.webhook_url, json=message, timeout=5)
            except Exception as e:
                self._display.warning(f"Slack notification failed: {e}")
```

### Custom Module

```python
#!/usr/bin/env python3
# library/deploy_app.py
"""Custom Ansible module to deploy application archives."""

from ansible.module_utils.basic import AnsibleModule
import os
import subprocess

DOCUMENTATION = """
module: deploy_app
short_description: Deploy application from archive
description:
  - Extracts an application archive and sets up symlinks for zero-downtime deployment
options:
  archive:
    description: Path to the application archive
    required: true
    type: str
  deploy_dir:
    description: Base deployment directory
    required: true
    type: str
  version:
    description: Version string for the release directory
    required: true
    type: str
"""

def run_module():
    module_args = dict(
        archive=dict(type="str", required=True),
        deploy_dir=dict(type="str", required=True),
        version=dict(type="str", required=True),
    )

    result = dict(changed=False, message="", release_dir="")
    module = AnsibleModule(argument_spec=module_args, supports_check_mode=True)

    archive = module.params["archive"]
    deploy_dir = module.params["deploy_dir"]
    version = module.params["version"]
    release_dir = os.path.join(deploy_dir, "releases", version)
    current_link = os.path.join(deploy_dir, "current")

    # Check if this version is already deployed
    if os.path.exists(release_dir):
        result["message"] = f"Version {version} already deployed"
        result["release_dir"] = release_dir
        module.exit_json(**result)

    if module.check_mode:
        result["changed"] = True
        result["message"] = f"Would deploy {version} to {release_dir}"
        module.exit_json(**result)

    # Create release directory and extract archive
    os.makedirs(release_dir, exist_ok=True)
    rc, stdout, stderr = module.run_command(
        f"tar -xzf {archive} -C {release_dir} --strip-components=1"
    )

    if rc != 0:
        module.fail_json(msg=f"Extraction failed: {stderr}")

    # Update symlink atomically
    tmp_link = f"{current_link}.tmp"
    if os.path.lexists(tmp_link):
        os.unlink(tmp_link)
    os.symlink(release_dir, tmp_link)
    os.rename(tmp_link, current_link)

    result.update(changed=True, message=f"Deployed {version}", release_dir=release_dir)
    module.exit_json(**result)

if __name__ == "__main__":
    run_module()
```

```yaml
# Using the custom module
- name: Deploy new application version
  deploy_app:
    archive: /tmp/myapp-{{ app_version }}.tar.gz
    deploy_dir: /opt/myapp
    version: "{{ app_version }}"
  register: deploy_result
  notify: Restart app service

- name: Show deployment info
  debug:
    msg: "Deployed to {{ deploy_result.release_dir }}"
```

---

## 20. CI/CD Integration with Ansible

### GitHub Actions Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy with Ansible

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: "Target environment"
        required: true
        default: staging
        type: choice
        options: [staging, production]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'staging' }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install Ansible
        run: |
          pip install ansible boto3 botocore

      - name: Install Ansible collections
        run: |
          ansible-galaxy collection install -r requirements.yml

      - name: Setup SSH key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.ANSIBLE_SSH_PRIVATE_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan -H ${{ secrets.DEPLOY_HOST }} >> ~/.ssh/known_hosts

      - name: Write vault password
        run: echo "${{ secrets.ANSIBLE_VAULT_PASSWORD }}" > ~/.vault_pass
        
      - name: Run Ansible Playbook
        env:
          ANSIBLE_HOST_KEY_CHECKING: "False"
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        run: |
          ansible-playbook \
            -i inventory/${{ github.event.inputs.environment || 'staging' }}.yml \
            playbooks/deploy.yml \
            --vault-password-file ~/.vault_pass \
            --private-key ~/.ssh/deploy_key \
            -e "app_version=${{ github.sha }}" \
            -e "app_env=${{ github.event.inputs.environment || 'staging' }}" \
            -v

      - name: Cleanup secrets
        if: always()
        run: |
          rm -f ~/.ssh/deploy_key ~/.vault_pass
```

### Jenkins Pipeline with Ansible

```groovy
// Jenkinsfile
pipeline {
    agent any
    environment {
        ANSIBLE_HOST_KEY_CHECKING = 'False'
        VAULT_PASS_FILE = credentials('ansible-vault-password')
        SSH_KEY = credentials('ansible-ssh-key')
    }
    parameters {
        choice(name: 'ENV', choices: ['staging', 'production'], description: 'Deployment target')
        string(name: 'APP_VERSION', defaultValue: '', description: 'App version to deploy')
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Lint') {
            steps {
                sh 'ansible-playbook --syntax-check -i inventory/${ENV}.yml playbooks/deploy.yml'
                sh 'ansible-lint playbooks/deploy.yml'
            }
        }
        stage('Deploy') {
            steps {
                withCredentials([file(credentialsId: 'ansible-ssh-key', variable: 'SSH_KEY_FILE')]) {
                    sh """
                        ansible-playbook \
                            -i inventory/${params.ENV}.yml \
                            playbooks/deploy.yml \
                            --vault-password-file ${VAULT_PASS_FILE} \
                            --private-key ${SSH_KEY_FILE} \
                            -e "app_version=${params.APP_VERSION}" \
                            -e "app_env=${params.ENV}" \
                            -v
                    """
                }
            }
        }
        stage('Verify') {
            steps {
                sh """
                    ansible-playbook \
                        -i inventory/${params.ENV}.yml \
                        playbooks/verify.yml \
                        --private-key ${SSH_KEY_FILE}
                """
            }
        }
    }
    post {
        failure {
            slackSend(color: 'danger', message: "❌ Ansible deploy FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
        }
        success {
            slackSend(color: 'good', message: "✅ Ansible deploy SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
        }
    }
}
```

---

## 21. Performance Tuning & Optimization

### ansible.cfg Tuning

```ini
[defaults]
forks              = 50            # Parallel connections (default: 5)
gathering          = smart         # Only gather facts if not cached
fact_caching       = jsonfile      # Cache facts to disk
fact_caching_connection = /tmp/ansible_facts_cache
fact_caching_timeout = 86400       # Cache for 24 hours
host_key_checking  = False
stdout_callback    = yaml
callback_whitelist = profile_tasks, timer

[ssh_connection]
pipelining         = True          # Reduce SSH operations (huge speedup)
ssh_args           = -o ControlMaster=auto -o ControlPersist=600s -o BatchMode=yes
control_path       = %(directory)s/%%h-%%r

[connection]
timeout = 10
```

### Playbook Optimization Techniques

```yaml
# 1. Disable facts when not needed
- name: Fast tasks (no facts)
  hosts: all
  gather_facts: no
  tasks:
    - name: Simple ping
      ping:

# 2. Use package module instead of apt/yum for cross-platform plays
- name: Install git
  package:
    name: git
    state: present

# 3. Batch package installs (one task instead of many)
# BAD — one task per package
- name: Install nginx
  apt: name=nginx state=present
- name: Install curl
  apt: name=curl state=present
# GOOD — one task for all
- name: Install packages
  apt:
    name: [nginx, curl, git, vim]
    state: present

# 4. Use async for long-running tasks
- name: Run long upgrade
  apt:
    upgrade: dist
  async: 3600                      # Max time to run (seconds)
  poll: 0                          # Fire and forget (don't wait)
  register: long_task

- name: Wait for upgrade to complete
  async_status:
    jid: "{{ long_task.ansible_job_id }}"
  register: job_result
  until: job_result.finished
  retries: 360
  delay: 10

# 5. Serial for rolling updates (not all hosts at once)
- name: Rolling app update
  hosts: webservers
  serial:
    - 1           # First: 1 host (canary)
    - 25%         # Then: 25% at a time
    - 50%         # Then: 50%

# 6. Strategy plugins
- name: Use free strategy (hosts don't wait for each other)
  hosts: all
  strategy: free   # default: linear (hosts run in lockstep)
  tasks:
    - name: Run independent tasks
      command: echo "hello"

# 7. Include tasks dynamically (only load what's needed)
- name: Include environment-specific tasks
  include_tasks: "{{ app_env }}.yml"
```

### Profiling

```bash
# Enable task timing
ANSIBLE_CALLBACK_WHITELIST=profile_tasks ansible-playbook site.yml

# Output shows time per task:
# Tuesday 16 January 2024  14:30:05 +0530 (0:00:15.234)
# ===============================================================================
# Install packages -------------------------------------- 45.23s
# Deploy nginx config ----------------------------------- 12.01s
# Restart nginx ------------------------------------------  0.52s
```

---

## 22. Ansible in Kubernetes & Container Environments

### Kubernetes Module (kubernetes.core)

```bash
# Install collection
ansible-galaxy collection install kubernetes.core
pip3 install kubernetes
```

```yaml
# deploy_k8s.yml
---
- name: Deploy application to Kubernetes
  hosts: localhost
  gather_facts: no
  vars:
    k8s_namespace: production
    app_image: "myregistry/myapp:{{ app_version }}"

  tasks:
    - name: Create namespace
      kubernetes.core.k8s:
        name: "{{ k8s_namespace }}"
        api_version: v1
        kind: Namespace
        state: present

    - name: Deploy application
      kubernetes.core.k8s:
        state: present
        definition:
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: myapp
            namespace: "{{ k8s_namespace }}"
            labels:
              app: myapp
              version: "{{ app_version }}"
          spec:
            replicas: 3
            selector:
              matchLabels:
                app: myapp
            template:
              metadata:
                labels:
                  app: myapp
                  version: "{{ app_version }}"
              spec:
                containers:
                  - name: myapp
                    image: "{{ app_image }}"
                    ports:
                      - containerPort: 8080
                    env:
                      - name: APP_ENV
                        value: "{{ app_env }}"
                    resources:
                      requests:
                        memory: "128Mi"
                        cpu: "250m"
                      limits:
                        memory: "256Mi"
                        cpu: "500m"

    - name: Wait for rollout to complete
      kubernetes.core.k8s_rollout_status:
        name: myapp
        namespace: "{{ k8s_namespace }}"
        kind: Deployment

    - name: Verify pods are running
      kubernetes.core.k8s_info:
        kind: Pod
        namespace: "{{ k8s_namespace }}"
        label_selectors:
          - app=myapp
      register: pod_info

    - name: Show running pods
      debug:
        msg: "Pod {{ item.metadata.name }}: {{ item.status.phase }}"
      loop: "{{ pod_info.resources }}"
```

### Docker Management with Ansible

```yaml
# Manage Docker containers
- name: Manage application container
  community.docker.docker_container:
    name: myapp
    image: "myregistry/myapp:{{ app_version }}"
    state: started
    restart_policy: unless-stopped
    published_ports:
      - "{{ app_port }}:8080"
    env:
      APP_ENV: "{{ app_env }}"
      DB_HOST: "{{ db_host }}"
    volumes:
      - /opt/myapp/config:/app/config:ro
      - /var/log/myapp:/app/logs
    networks:
      - name: myapp_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      traefik.enable: "true"
      traefik.http.routers.myapp.rule: "Host(`{{ app_domain }}`)"
```

---

## 23. Best Practices & Anti-Patterns

### Best Practices ✅

```yaml
# 1. Use meaningful names for everything
- name: "Install nginx web server (required for app serving)"  # ✅ Descriptive
  apt:
    name: nginx
    state: present

- name: "apt"     # ❌ Meaningless

# 2. Use specific state for packages
  apt:
    name: nginx
    state: present    # ✅ — idempotent: "ensure installed"
    # state: latest   # ⚠️ Use carefully — can break things mid-deployment

# 3. Always validate templates
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    validate: nginx -t -c %s       # ✅ Verify before placing

# 4. Use notify + handlers instead of direct restarts
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Reload nginx             # ✅ Handler runs once at end

# 5. Set defaults in role defaults/main.yml
# roles/nginx/defaults/main.yml
nginx_port: 80                    # ✅ Sensible default that users can override

# 6. Use tags for granular execution
  tags:
    - nginx
    - configure
    - webserver

# 7. Prefix vault variables
vault_db_password: "..."          # ✅ Clear that this is from vault
db_password: "{{ vault_db_password }}"   # ✅ Clean separation

# 8. Comment complex tasks
- name: Update kernel parameters
  sysctl:
    name: net.core.somaxconn
    value: "65535"
    sysctl_set: yes
  # Needed for high-concurrency nginx — default 128 is too low

# 9. Use assert for input validation
- name: Validate required variables
  assert:
    that:
      - app_env in ['staging', 'production']
      - db_host | length > 0
    fail_msg: "Invalid configuration"

# 10. Test with --check --diff before real runs
```

### Anti-Patterns ❌

```yaml
# ❌ Using shell/command when a module exists
- name: Install nginx
  shell: apt-get install -y nginx    # Wrong — use apt module

# ❌ Ignoring all errors blindly
- name: Critical task
  command: /opt/migrate.sh
  ignore_errors: yes                  # Wrong — could hide real problems

# ❌ Hardcoding values
- name: Create user
  user:
    name: john_doe                    # Wrong — use variables
    password: "SuperSecret123"        # Wrong — use vault

# ❌ Not using become where needed (security risk)
- name: Configure sudoers
  copy:
    src: sudoers
    dest: /etc/sudoers               # Wrong — needs become: yes

# ❌ Using 'latest' for production packages
  apt:
    name: mysql-server
    state: latest                     # Risky in production

# ❌ No error handling on critical tasks
- name: Backup database
  command: mysqldump -u root mydb > /tmp/backup.sql
  # No register, no failed_when, no verification

# ❌ Massive tasks file with no roles
# playbooks/everything.yml — 500 tasks in one file
# Use roles for organization

# ❌ Not using version control for playbooks
# ❌ Committing vault passwords to git
# ❌ Running playbooks without --check first in production
```

### Security Best Practices

```yaml
# 1. Least privilege — only become when necessary
- name: Deploy app files
  copy:
    src: app.jar
    dest: /opt/myapp/
  become: yes
  become_user: deploy              # Become specific user, not root

# 2. Validate file permissions
- name: Secure config file
  file:
    path: /etc/myapp/secrets.conf
    mode: '0600'                   # Only owner can read/write
    owner: deploy
    group: deploy

# 3. Use no_log for sensitive tasks
- name: Set database password
  mysql_user:
    name: appuser
    password: "{{ vault_db_password }}"
    priv: "appdb.*:ALL"
  no_log: true                     # Prevent password appearing in logs

# 4. Sanitize user input
- name: Create user
  user:
    name: "{{ username | regex_replace('[^a-zA-Z0-9_-]', '') }}"
    state: present

# 5. Verify checksums for downloads
- name: Download release binary
  get_url:
    url: "https://releases.example.com/app-{{ app_version }}.tar.gz"
    dest: /tmp/app.tar.gz
    checksum: "sha256:{{ app_checksum }}"   # Verify integrity
```

---

## 24. Summary & Further Learning

### Key Concepts Summary

| Concept | Why It Matters |
|---|---|
| **Idempotency** | Run playbooks safely multiple times — the result is always the same desired state |
| **Roles** | Package and reuse automation; enforce consistent structure |
| **Variables + Vault** | Separate data from logic; secure sensitive values |
| **Handlers** | Efficient restarts — only when something actually changed |
| **Templates** | Dynamic configs using Jinja2 — one template for all environments |
| **Galaxy Collections** | Don't reinvent the wheel; leverage 10,000+ community modules |
| **Tags** | Granular execution — run only what you need |
| **Dynamic Inventory** | Auto-discover infrastructure from AWS, GCP, CMDBs, etc. |
| **Check Mode** | Safe dry-run — see what would change before applying |

### Suggested Learning Path

```
Phase 1 — Foundation (Weeks 1-2)
  ✅ Install Ansible, configure inventory
  ✅ Master ad-hoc commands
  ✅ Write your first 3 playbooks
  ✅ Understand variables and facts

Phase 2 — Intermediate (Weeks 3-4)
  ✅ Create your first role (nginx or mysql)
  ✅ Use Jinja2 templates
  ✅ Implement Ansible Vault for secrets
  ✅ Write handlers and use conditionals/loops

Phase 3 — Advanced (Weeks 5-8)
  ✅ Build dynamic inventory (AWS EC2)
  ✅ Write a custom module in Python
  ✅ Integrate Ansible into CI/CD (Jenkins/GitHub Actions)
  ✅ Optimize playbooks with pipelining, async, caching
  ✅ Deploy to Kubernetes with kubernetes.core

Phase 4 — Mastery
  ✅ Publish a role to Ansible Galaxy
  ✅ Build a complete multi-tier infrastructure playbook
  ✅ Implement molecule for role testing
  ✅ Explore AWX / Ansible Automation Platform
```

### Practice Projects

1. **LAMP Stack Deployment** — Automate full Linux + Apache/Nginx + MySQL + PHP setup using roles
2. **Zero-Downtime App Deploy** — Rolling update with load balancer drain/restore
3. **AWS Infrastructure Provisioning** — Spin up VPC, subnets, EC2, RDS with Ansible + boto3
4. **Docker Compose to Ansible** — Convert a docker-compose.yml to Ansible container management
5. **Kubernetes GitOps Pipeline** — GitHub push → GitHub Actions → Ansible → K8s deployment
6. **Automated Patching** — OS patching playbook with pre/post health checks and rollback

### Further Learning Resources

| Resource | Description | URL |
|---|---|---|
| **Ansible Docs** | Official documentation (always current) | docs.ansible.com |
| **Ansible Galaxy** | Community roles and collections | galaxy.ansible.com |
| **Red Hat Training** | DO407 / EX294 Ansible courses | training.redhat.com |
| **Jeff Geerling's Blog** | Deep Ansible tutorials by the top contributor | jeffgeerling.com |
| **Molecule** | Role testing framework | ansible.readthedocs.io/projects/molecule |
| **AWX Project** | Open-source Ansible Tower (web UI + API) | github.com/ansible/awx |
| **Ansible Lint** | Best practice linting for playbooks | github.com/ansible/ansible-lint |
| **GitHub: ansible/ansible** | Source code — read to learn internals | github.com/ansible/ansible |

### Quick Reference Cheat Sheet

```bash
# === INVENTORY ===
ansible-inventory --list -y          # List inventory as YAML
ansible-inventory --graph            # Show group hierarchy
ansible all -m ping                  # Test all hosts

# === AD-HOC ===
ansible webservers -m apt -a "name=nginx state=present" --become
ansible all -m setup -a "filter=ansible_distribution*"
ansible all -m shell -a "uptime" -f 20

# === PLAYBOOKS ===
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml --check --diff
ansible-playbook site.yml --limit web01 --tags configure
ansible-playbook site.yml -e "env=production" --ask-vault-pass

# === VAULT ===
ansible-vault create secrets.yml
ansible-vault edit secrets.yml
ansible-vault encrypt_string 'mysecret' --name 'vault_key'

# === GALAXY ===
ansible-galaxy role init myrole
ansible-galaxy install -r requirements.yml
ansible-galaxy collection install amazon.aws

# === DEBUGGING ===
ansible-playbook site.yml -vvv
ansible-playbook site.yml --list-tasks
ansible-playbook site.yml --start-at-task "Deploy app"
```

---

> 💡 **The best way to master Ansible is to automate something you do manually every day.**
> Start small — a single task you repeat weekly. Build it into a role. Add tests. Share it on Galaxy.
> Automation is a skill built one playbook at a time. Keep writing, keep iterating. 🚀

---

*Ansible Mastery Guide | Version 1.0 | Built for DevOps practitioners*

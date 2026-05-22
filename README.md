# yup: Stop getting wrecked by zero-day AUR updates

Most Arch Linux users think the biggest risk to their system is a broken dependency. 

BUT the real threat is a compromised maintainer account on the Arch User Repository (AUR). You run a standard update, pull a hijacked package, and suddenly a malicious commit is running root commands on your machine.

Why aren't you putting a buffer between your system and fresh AUR commits?

Here is the fix ↓

**yup** (Yay Update Protector) is a POSIX-compliant Bash wrapper that forces a strict 24-hour quarantine on every AUR package you try to install or update. 

If a package was modified on the AUR within the last 86,400 seconds, `yup` hits the brakes. Waiting a single day gives the community time to catch malicious code before you blindly install it.

Also dont download and run any script without reading it, Even 
read this script first.

## How it actually works

`yup` doesn't break your workflow. It intercepts your command line arguments and pings the Arch Linux RPC API (`https://aur.archlinux.org/rpc/`) to check the exact `LastModified` timestamp of your target packages using `jq`.

* **Older than 24 hours?** It hands the package off to `yay` for a normal install.
* **Younger than 24 hours?** If you are running a system upgrade (`-Syu`), it dynamically builds an `--ignore` list. Your safe packages update, and the fresh ones are held back. If you are doing a manual install, it outright aborts.
* **Official Arch repos?** Packages from official repos (like `core` or `extra`) don't exist in the AUR API. `yup` recognizes this and passes them through instantly with zero delay.

## Installation

You need `curl` and `jq` for the API calls and JSON parsing. 

1. Install the dependencies:
```bash
sudo pacman -S curl jq
```

2. Clone and install `yup` one step at a time:

```bash
git clone https://github.com/ddroid/yup
cd yup
chmod +x yup
sudo mv yup /usr/local/bin/
```

3. (Optional) Alias it in your `.bashrc` or `.zshrc` so you never accidentally skip the check:

```bash
alias yay="yup"
```

## Usage

You don't need to learn a new syntax. Just use `yup` exactly like you already use `yay`. It handles all standard flags (like `--noconfirm` or `--needed`).

**Upgrade your entire system safely:**

```bash
yup -Syu
```

**Install a specific package:**

```bash
yup -S timeshift
```

**Remove a package:**
*(Security checks are automatically bypassed for removals and queries to keep things fast).*

```bash
yup -Rns timeshift
```

## Why I built this

Blindly trusting the bleeding edge is a terrible security policy. You don't need real-time, to-the-minute updates for a custom Spotify client, a Discord mod, or an obscure GTK theme.

Let the impatient users step on the zero-day landmines first. Protect your own machine.

## Contribution

Right now its just a random script by a random person on the internet, We can definately make it better (and maybe even a standard) through contributions. Create a Issue or Pull Request, I will be more than happy to get contributions to this small but important project.

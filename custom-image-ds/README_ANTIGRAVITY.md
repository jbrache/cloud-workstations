# **Optional**: Antigravity Steps if Enabled

**Huge Kudos to [Daniel Strebel](https://www.linkedin.com/in/danistrebel)** with the excelent steps and details: [Using Chrome Remote Desktop to run Antigravity on a Cloud Workstation (or just in a Container)](https://medium.com/google-cloud/using-chrome-remote-desktop-to-run-antigravity-on-a-cloud-workstation-or-just-in-a-container-d00296425a0f)
* Other Resources
  * [Running Antigravity on a browser tab](https://medium.com/google-cloud/running-antigravity-on-a-browser-tab-6298bb7e47c4)

Note the multiple `workstation-container-antigravity-v*` folders.
* `workstation-container-antigravity-v1` - Method used: [Using Chrome Remote Desktop to run Antigravity on a Cloud Workstation (or just in a Container)](https://medium.com/google-cloud/using-chrome-remote-desktop-to-run-antigravity-on-a-cloud-workstation-or-just-in-a-container-d00296425a0f)
* `workstation-container-antigravity-v2` - Method used: [Running Antigravity on a browser tab](https://medium.com/google-cloud/running-antigravity-on-a-browser-tab-6298bb7e47c4)
* `workstation-container-antigravity-v3-xpra` - Method used: [Extending Google Cloud Workstations containers to run any GUI based program](https://medium.com/@roken/extending-google-cloud-workstations-containers-to-run-any-gui-based-program-133d0f905106)

In terraform.tfvars, set `workstation-container-antigravity-v1` as:
* `workstation-container-antigravity-v1`
* `workstation-container-antigravity-v2`

# Steps when deploying: `workstation-container-antigravity-v1`
In the workstations section of the Google Cloud Console you should now see the workstation you just created:
[image]

Use the “Start” button to start the workstation. Once it shows a “Launch” button the workstation is ready.

**Note:** The “Launch” button is a shortcut to the workstation gateway port forward for port 80 on the cloud workstation. Since we used the base workstation image as the start for our customization nothing is running on port 80 at that point and clicking the Launch button will show an error message. That’s working as intended.

Instead of the Launch button we’ll need to create an SSH connection to our Cloud Workstation. To do this you’ll need to use the gcloud-wrapped SSH command that the UI has a handy shortcut for:

[image]

It’ll show you a `gcloud` command similar to the one below that you can run to get an `SSH` shell into your Cloud Workstation.

```bash
export PROJECT_ID="the-foo-bar"
export REGION="us-central1"
export WORKSTATION_CLUSTER="tf-ws-cluster"
export WORKSTATION_CONFIG="tf-ws-config-antigravity"

export USER="jose@jbrache.altostrat.com"
export USERNAME=$(echo "$USER" | sed 's/[@.]/_/g')

gcloud workstations ssh \
  --project=$PROJECT_ID \
  --cluster=$WORKSTATION_CLUSTER \
  --config=$WORKSTATION_CONFIG \
  --region=$REGION \
  --user=$USERNAME \
  antigravity-ws-jose
```
## Chrome Remote Desktop Connection:
The Remote Desktop Connection part is quite simple. You need to head to the Remote Desktop [headless](https://remotedesktop.google.com/headless) setup page and click “Begin” on the setup dialog.

[image]]

Ignore the instructions to install Chrome Remote Desktop on your remote computer (the container build took care of that for you) and click “Next” and then “Authorize” to get to the authorization commands. Note that these commands contain a sensitive — code argument that represents a temporary token that ties it to your account. You’ll want to copy the entire snippet under “Debian Linux” and paste it to your Cloud Workstation SSH terminal from before.

[image]

Generated Setup Commands
When you copy it to your workstation terminal, consider adding a memorable display name with `--display-name=antigravity-ws-jose` (you’ll thank me later.)

```
jose_jbrache_altostrat_com@antigravity-ws-jose:~$ DISPLAY= /opt/google/chrome-remote-desktop/start-host \
--code="XXX" \
--redirect-url="https://remotedesktop.google.com/_/oauthredirect" \
--name=$(hostname) \
--display-name=antigravity-ws-jose
```

The dialog will ask you for a 6-digit pin. Make sure you’ll remember this because it will be used later when you log-in with your Cloud Workstation. When everything is done you should see a message that confirms the host is ready.

`Host started successfully.`

This message is a bit misleading. If you head to the access page for Chrome Remote Desktop you’ll still see this “starting” message:

[image]

Instead of waiting you can run the start command that we’ve also added to our runtime script so subsequent Cloud Workstation starts will run this automatically:

`/opt/google/chrome-remote-desktop/chrome-remote-desktop --start`

This should finish with a message saying:

`Host ready to receive connections.`

At which point the Chrome Remote Desktop page also shows the online connection:

[image]

When you click it you’ll see the PIN input where you enter the PIN that you created before:

[image]

And there you go your browser shows your desktop in the Cloud Workstation:

[image]

Launch a new Terminal and enter `antigravity`:

[image]

And the Antigravity setup dialog appears that takes you through the initial configuration and authentication steps. Once the onboarding is completed, Antigravity launches and is ready for some action.

[image]

Of course, because it’s the beginning of the year. We’ll use the power of Gemini in Antigravity to lazy vibe code an application that should help us track our laziness in other domains:

[image]

## (Optional) Running the Antigravity Image Locally
For me, the option of running an Antigravity Image with UI locally was more of a proof of concept and quick smoke test during the container development. But it did prove that technically you could also run the image that we built (or a slimmer version of it without the Cloud Workstation dependencies) locally to help with the sandbox concern that we mentioned at the beginning of this post. Obviously the enterprise and resource constraints still apply in this case.

The steps to run this are quite simple:

```bash
# Build the image
docker build -t antigravity-local

# Run the container interactively with a mounted /home directory
docker run -it --rm -v "$(pwd)/chrome-data:/home/user:rw" antigravity-local

# Get an interactive shell to run the Chrome Remote Desktop initialization
docker exec -it <container id> bash
```

## Resources:
* [Using Chrome Remote Desktop to run Antigravity on a Cloud Workstation (or just in a Container)](https://medium.com/google-cloud/using-chrome-remote-desktop-to-run-antigravity-on-a-cloud-workstation-or-just-in-a-container-d00296425a0f)
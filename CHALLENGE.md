# Cloud engineer technical challenge: GitOps for a robot fleet

Oct 13, 2026, @Carlos

## Introduction

This challenge asks you to design a GitOps setup for the software and configuration that runs our robots, and to build one small, working piece of it. Plan for 3 to 4 hours in total and stop there. You will probably not finish everything, and that is expected. List what you left out and how you would approach it, because we want to see how you prioritize and plan, not only what you build.

The scenario is simplified but close to problems we deal with today. There are no hidden trick questions and no single right answer. Where something is unclear, make a reasonable assumption, write it down, and move on.

Your submission is the starting point for the follow-up interview. You will walk us through your design and your code, and we will discuss the trade-offs, the parts you left out, and how the setup would grow over time.

## The scenario

You have just joined the Infrastructure & Data team, and your first project is to make releases to the robot fleet safe, traceable and driven from Git. In this scenario the fleet is about 400 robots at 60 customer sites. Each robot has a Linux controller that runs four containerized applications, each owned by a different team.

| Application | Owning Team | What it does | Release cadence | Config it needs |
| --- | --- | --- | --- | --- |
| Robot runtime | Robot Software | Motion planning, digital twin, drivers for the robot modules | Every 4 to 6 weeks | Module layout, joint limits, calibration references |
| Program runtime | Applications | Runs the programs customers build in our no-code programming tool | Every 2 weeks | Feature flags, program storage settings |
| Vision service | Perception | Runs computer vision models on camera input | Service monthly, models weekly | Model version, camera parameters per cell |
| Edge agent | Infrastructure & Data | Connects the robot to the fleet management platform for updates, telemetry and remote access | As needed | Platform endpoint, telemetry settings, credentials |

A few constraints shape the problem. Many robots sit behind customer firewalls and only reach the cloud through an outbound connection. Some go offline for days at a time. Customers decide when updates may happen, usually in a maintenance window between shifts, because a robot that restarts mid-shift stops a production line.

The current state has grown organically and causes these problems:

- Each team builds and releases in its own way, and nobody can easily answer which versions are running on which robot.
- Configuration lives in three places: application repositories, the fleet management platform's UI, and files on the robot that field engineers edit during commissioning (for example calibration and gripper settings).
- Incompatible combinations have reached customers. In the most recent case, a new vision model required a newer robot runtime than some sites were running.
- Rollback means a field engineer connecting to the robot and reverting by hand.
- Some site credentials, such as tokens for customer PLC integrations, are stored in plain text in a config repository.

## Part A: design document

Write a design document that proposes how releases and configuration should flow from Git to the robots. Length, structure and format are up to you, and diagrams are welcome if they help. The questions below are the areas we care about. Use them as a guide rather than a checklist: go deep where you think it matters most, stay brief or skip where it doesn't, and tell us why.

1. Release flow. How does a change move from a merged MR to dev, to robots in our internal lab, to a few canary customer sites, and then to the whole fleet? What gates each step, who or what approves it, and how do customer maintenance windows fit in?
2. Releasing four applications together. How do you make sure only compatible versions of the four applications are deployed together, without forcing all four teams onto the same release schedule?
3. Configuration in Git. How do you structure configuration so that global defaults, environments, customer sites and individual robots can each override what they need? Which layer wins, and how does someone see the final configuration a given robot will receive?
4. Changes made in the field. Field engineers need to adjust calibration and gripper settings while standing next to a robot, sometimes without network access. How do those changes end up in Git without making Git a bottleneck, and how do you detect drift?
5. Rollback and offline robots. How do you roll back a bad release, and what happens to a robot that was offline for a week and comes back two releases behind?
6. Secrets. How do credentials get to the robots without being stored in plain text in Git?

State the assumptions you make about tooling. You can use tools you know, such as Argo CD, Flux or a custom agent on the robot, but the reasoning matters more to us than the specific product.

## Part B: configuration tooling

Build something that makes configuration changes safer and easier to review, plus a CI workflow that runs it on pull requests. You will receive a Git repository with sample configuration in this layout:

```
config/
  defaults/          runtime.yaml, program.yaml, vision.yaml, agent.yaml
  environments/      dev.yaml, prod.yaml
  sites/             robco-lab.yaml, customer-a.yaml, customer-b.yaml, ...
  robots/            rb-0142.yaml, rb-0143.yaml, ...
releases/            2026.09.2.yaml, 2026.10.1.yaml
compatibility.yaml   rules such as "vision >= 3.2 requires runtime >= 5.0"
schema/              JSON Schemas for the final configuration and for release files
```

Each robot file names its site, each site names its environment and the release it is pinned to, and each release file pins a version of all four applications. Every layer uses the same top-level keys (`runtime`, `program`, `vision`, `agent`). When layers are merged, maps are merged key by key and all other values, including lists, are replaced by the more specific layer.

Use whatever language and tools you like; the CI runner image comes with Python and Go. What you build is up to you. Some ideas:

- Render the final configuration of any robot by merging the four layers.
- Validate final configurations and release files against the schemas in `schema/`.
- Check that each site's release satisfies the rules in `compatibility.yaml`.
- Compare two Git revisions and show which robots' final configuration changed.
- Catch credentials that shouldn't be in Git.

You won't have time for all of this, and we don't expect you to. Pick what you think matters most for the people reviewing configuration changes, and explain your choice in the README.

Then add a CI workflow in `.gitea/workflows/` that runs your work on pull requests and makes its output easy for a reviewer to find. The repository has three example branches with typical changes, a fleet-wide default change, a single-site tweak and a release upgrade, that you can use to try it out.

Test it in whatever way you think is right, and keep the code at a level you would be comfortable having a teammate review.

## Something to think about: developer experience

You don't need to write or build anything for this part. In the interview we would like to talk about what your setup feels like for the engineers in the four application teams. For example, imagine an engineer on the Perception team who wants a new vision model running on three lab robots by Friday, and think about what their path would look like.

## What to submit

Everything runs locally, and you only need Docker, Git and Make. Clone the starter repository from the link in your invitation email and run `make up`. This starts a local Gitea server with Gitea Actions and a runner, copies the repository into it, and sets it up as your `origin` remote. The README in the repository has the details. Gitea Actions uses the GitHub Actions workflow syntax. We use GitLab day to day and chose Gitea only so you need no account or cloud setup, so we care about the shape of your workflow, not the CI dialect.

Push your work to `origin` and open at least one pull request in Gitea, so we can see your workflow run. Then send us the repository as a zip that includes the `.git` folder.

Your submission should contain:

- The design document from Part A, in the repository, in any format we can open without special software.
- What you built for Part B, and the CI workflow.
- A README that explains how to run what you built, what you chose to build and why, and the assumptions you made, plus what you didn't get to and how you would approach it.

You don't need a cloud account or any paid services. You may use any tools you normally work with, including AI assistants, as long as you can explain and defend every part of your submission in the interview.

If something in this brief blocks you, email us. We would rather answer a question than have you lose time on it.

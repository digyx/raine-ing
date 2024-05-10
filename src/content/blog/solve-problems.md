---
title: Solve the Problems You Actually Have
description: Premature optimization will be the death of me.
pubDatetime: 2024-05-10T07:00:00
tags:
  - programming
---

Programmers have this nasty habit of thinking too hard. When trying to solve a problem, we start inventing new problems that don't actually exist, but we'd like for them to exist. Why? Because it gives us a reason to solve the problem in a novel way rather than implementing the same, well-known solution for the 100th time.

Do you really need microservices? [Probably not.](https://blogs.newardassociates.com/blog/2023/you-want-modules-not-microservices.html) But it's way more interesting than just using a monolithic app you deploy via a single docker container. With microservices, you can play with an event driven architecture vs REST API interactions. Do we use CQRS? Oh, we can totally use CQRS instead of calling a function.

Do you reall need SPAs? SvelteKit is amazing to work with compared to React or Vue, but you'll probably be fine with [a template engine](https://pkg.go.dev/html/template). Need to send data to the server? Use [HTMX](https://htmx.org/) or HTML forms.

Do you really need to rewrite your Python app in Rust? Spend the time to cleanup/refactor the existing code then add Pyright to your CI checks. You'll get 90% of the benefits for 10% of the costs.

Focus on the actual hard problems. Use a profiler to find bottleneck _when performance negatively impacts you_. Is your problem a lack of users? Focus on getting people to use your thing either through marketing (_shudders_) or creating features people actually want to use.

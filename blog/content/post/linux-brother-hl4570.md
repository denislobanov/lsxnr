---
title: "Brother HL-4570CDW printers on Linux"
date: 2018-04-06
tags: ["linux", "cups"]
---

For whatever reason, I always find that any printer at work will always be the one that doesn't work with Linux. Maybe that's just because all printers don't work with Linux ;p But luckily to get the printer to work all it took was a ppd file.

<!--more-->
I started with an existing ppd file from a similar printer in the same family; this way I didn't have to specify as much configuration about page sizes etc and, as a first attempt I just changed all the names to the new printer. Fortunately that was all it took!

<br/>
You can find the [file itself here](/misc/hl4570cdw.ppd).  


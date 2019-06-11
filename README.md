# Greenpeace Planet 4 Styleguide deployment

![Planet4](./planet4.png)

## Description

This repository controls the building of docker images and the helm deployment of the Planet4 Styleguide static content app.

The actual Styleguide app can be found on its own [repository](https://github.com/greenpeace/planet4-styleguide) 

## How this works

The build and deployment is happening automatically whenever: 
- There are commits to the master repository of the styleguide [repository](https://github.com/greenpeace/planet4-styleguide)
- There are new tags created in the styleguide [repository](https://github.com/greenpeace/planet4-styleguide)

The above changes trigger (via the circleCI API) a rebuild of the develop and master related workflows of the current repository. 

These in turn do the following: 

- Checkout the relevant code of the styleguide [repository](https://github.com/greenpeace/planet4-styleguide) (either the latest code of the master theme, or the latest tag)
- Create a docker image with the above code in the repository called "public"
- Push this docker image to the grc.io registry for the current application and tag it either `develop` or `latest`
- Run a helm deploy/update to create the necessary kubernetes resources so that this can be served by our kubernetes clusters

## Other things to note 

- This repository does not have its own helm chart. It utilises the helm chart [Planet4 static](https://github.com/greenpeace/planet4-helm-static) which can been created to accomodate all static applications 
- Commits to the master repository of the styleguide [repository](https://github.com/greenpeace/planet4-styleguide) get deployed at the url: https://develop.planet4.greenpeace.org/styleguide/
- New tags to the repository of the styleguide [repository](https://github.com/greenpeace/planet4-styleguide) get deployed at the url: https://planet4.greenpeace.org/styleguide/
- At the bottom left corner of those implementations you can see the hash (or the tag number) of the code used to build it. 



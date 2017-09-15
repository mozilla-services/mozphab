import json
import os

from invoke import task

DOCKER_IMAGE_NAME = os.getenv('DOCKERHUB_REPO', 'mozilla/mozphab')


@task
def version(ctx):
    """Print version information in JSON format."""
    print(json.dumps({
        'commit':
        os.getenv('CIRCLE_SHA1', None),
        'version':
        os.getenv('CIRCLE_SHA1', None),
        'source':
        'https://github.com/%s/%s' % (
            os.getenv('CIRCLE_PROJECT_USERNAME', 'mozilla-services'),
            os.getenv('CIRCLE_PROJECT_REPONAME', 'mozphab')
        ),
        'build':
        os.getenv('CIRCLE_BUILD_URL', None),
    }))


@task
def build(ctx):
    """Build the docker image."""
    ctx.run('docker build --pull -t {image_name} .'.format(
        image_name=DOCKER_IMAGE_NAME
    ))


@task
def imageid(ctx):
    """Print the built docker image ID."""
    ctx.run("docker inspect -f '{format}' {image_name}".format(
        image_name=DOCKER_IMAGE_NAME,
        format='{{.Id}}'
    ))

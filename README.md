# Navigator
## Description
DB-Navigator like App with a better UI and open-source.

## Setup
To use the App you need a working Instance of [db-rest](https://github.com/derhuerst/db-rest)
In The root of /navigator create a .env File with your API Base URL
```
#navigator/.env
API_URL=<your_api_url_here>:<your_port_here>
```
Then run
```
flutter pub run build_runner build --delete-conflicting-outputs
```
Now you should be able to compile the App and it will use your API Server
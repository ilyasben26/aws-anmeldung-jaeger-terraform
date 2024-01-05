![logo_aj](https://github.com/ilyasben26/aws-anmeldung-jaeger/assets/73348981/611c8cd8-b3ce-4e4d-bbee-ea28b263fde1)

Visit here: https://anmeldung-jaeger.com

# 1. Introduction
When moving in to another residence in Germany, the Anmeldung is know to be quite the hassle, especially when the appointments are few and highly sought after. But what if you could immediately get notified as soon as an appointment is available? That is exactly what this small project of mine aims to accomplish. 

With the help of AWS's serverless services, the goal is to create a solution that continuously checks the respective portals for most major German cities, in search of those juicy free appointments and quickly notifies the users so that they can go ahead and secure their spot. 

Ideally, I would build this solution using only severless services in AWS and without exceeding the AWS free tier; costs must be kept to a minimum.

I will be using the following services:
- *AWS Lambda*: for crawling the portals and publishing the results to S3 and notifying users via SNS.
- *Amazon DynamoDB*: to act as a cache for persisting variables between Lambda functions.
- *Amazon SNS*: to notify users.
- *Amazon S3*: for creating a website which will display the available appointments as well as storing the results of the Lambda functions.
- *Amazon Route 53*: to register and configure the domain.
- *Amazon EventBridge*: to run the lambda functions every 5 minutes.
- *AWS IAM*: to configure the necessary roles and permissions.
- *AWS Amplify*: to host the front-end website.
- *Amazon API Gateway*: to enable access to the backend via the frontend.

Moreover, I will manage some of the infrastructure using Terraform, the following will be managed with Terraform:
- *AWS Lambda*
- *Amazon S3*
- *Amazon EventBridge*

The rest will be managed using the AWS platform.

# 2. The Architecture

![Anmeldung-Jaeger-Architecture](https://github.com/ilyasben26/aws-anmeldung-jaeger-terraform/assets/73348981/e3f19063-90b8-4319-ae74-1682974002ed)

# 3. Development
## 1. Reverse Engineering the Portal 
In previous iterations of this project *link GitHub*, I wrote a python script that would use a selenium headless browser to crawl the website. This previous solution proved to be too clunky and with too much overhead, so for this iteration, I will try to only use GET requests to get the data that is needed from the website. This is also better since it will make it way faster and hence cost less in terms of resources.

The first step is to understand how the portal works, for this I will be going through a normal workflow to book an appointment and analyse each request made via the browser using BurpSuite, that way I can reproduce the same steps programmatically inside the Lambda function using Python.

I will first create the function for the Bremen portal.
Bremen uses a unified portal for booking all kinds of appointments, the first page looks like as follows:

![Pasted image 20231222151043](https://github.com/ilyasben26/aws-anmeldung-jaeger/assets/73348981/89ba5764-d556-4138-bb31-3695cd146ff4)

As we can see the initial GET request to the portal is made via the url `https://termin.bremen.de/termine/`, from this request, we learn the following:
- A session cookie called `tvo_session` is set to establish a session. The session lasts for 24 minutes as shown below

After choosing one of the options from the list, a GET request is made to the following url `https://termin.bremen.de/termine/select2?md=5`:

![Pasted image 20231222151512](https://github.com/ilyasben26/aws-anmeldung-jaeger/assets/73348981/49bb24bf-1406-4931-a888-02d692386572)

Upon further testing, the following is apparent:
- `select2` signifies that we are on the second step of the booking process
- the `md` parameter here is referring which option was chosen, in this case it was BürgerServiceCenter-Mitte, which if we look at the first screenshot does coincide with the sixth position (by indexing at 0), hence why `md=5` points to it.

Let's now try and select which kind of appointments I want to book, I will focus solely on Anmeldung appointments. After clicking a bunch of buttons, I get this curious request being made:
```HTTP
GET /termine/location?mdt=701&select_cnc=1&cnc-8580=0&cnc-8582=0&cnc-8583=0&cnc-8587=0
&cnc-8597=0&cnc-8579=0&cnc-8596=0&cnc-8599=0&cnc-8600=0&cnc-8797=1&cnc-8790=1
&cnc-8588=0&cnc-8591=1&cnc-8798=0&cnc-8573=0&cnc-8844=0&cnc-8867=0&cnc-8789=0
&cnc-8575=0&cnc-8578=0&cnc-8590=0 HTTP/1.1
```
After some testing, I came to the following conclusions:
- `mdt` is an id for which location the appointment is booked.
- `select_cnc` must always be set to 1.
- `cnc-$$$$` are used for tracking which services the user wants to book and how many of them, for Anmeldung services, it is either set to 1 or 0.

After this request, we get a summary page of all the services we want to book:

![Pasted image 20231222153212](https://github.com/ilyasben26/aws-anmeldung-jaeger/assets/73348981/f6808494-f45e-40cb-95de-783ff5bb2b50)

After clicking on that `auswählen` button, the following happens:
- A post request is made:
```HTTP
POST /termine/location?mdt=701&select_cnc=1&cnc-8580=0&cnc-8582=0&cnc-8583=0
&cnc-8587=0&cnc-8597=0&cnc-8579=0&cnc-8596=0&cnc-8599=0&cnc-8600=0&cnc-8797=1
&cnc-8790=1&cnc-8588=0&cnc-8591=1&cnc-8798=0&cnc-8573=0&cnc-8844=0&cnc-8867=0
&cnc-8789=0&cnc-8575=0&cnc-8578=0&cnc-8590=0 HTTP/1.1
Host: termin.bremen.de
Cookie: tvo_session=3uk7kduf8iuei2d4cikb17ogll
...
...
...

loc=680&gps_lat=999&gps_long=999&select_location=B%C3%BCrgerServiceCenter-Mitte+ausw%C3%A4hlen
```
- Then a GET request:
``` HTTP
GET /termine/suggest HTTP/1.1
Host: termin.bremen.de
Cookie: tvo_session=3uk7kduf8iuei2d4cikb17ogll
User-Agent: Mozilla/5.0 (X11; Linux aarch64; rv:109.0) Gecko/20100101 Firefox/115.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate, br
Referer: https://termin.bremen.de/termine/location?mdt=701&select_cnc=1&cnc-8580=0&cnc-8582=0&cnc-8583=0
&cnc-8587=0&cnc-8597=0&cnc-8579=0&cnc-8596=0&cnc-8599=0&cnc-8600=0&cnc-8797=1&cnc-8790=1&cnc-8588=0&cnc-8591=1
&cnc-8798=0&cnc-8573=0&cnc-8844=0&cnc-8867=0&cnc-8789=0&cnc-8575=0&cnc-8578=0&cnc-8590=0
Dnt: 1
Upgrade-Insecure-Requests: 1
Sec-Fetch-Dest: document
Sec-Fetch-Mode: navigate
Sec-Fetch-Site: same-origin
Sec-Fetch-User: ?1
Te: trailers
Connection: close
```

After analysing these two requests and some testing, I came to the following conclusions:
- The browser asked to know my location before sending the POST request, this has something to do with `gpc_lat` and `gps_long` parameters, it seems like this is being used to suggest which location is closest to the user and has no importance for the workflow. If the user choose to block the location request, these two parameters are set to 999.
- `loc` and `select_location` are used for the location. `loc` is an ID and `select_location` always has the name of the location plus *auswählen*.

The last GET request to `/termine/suggest` is used to fetch the results of the previous POST request by showing the user which appointments are available, in case now appointment is available, the following is shown:

![Pasted image 20231222154717](https://github.com/ilyasben26/aws-anmeldung-jaeger/assets/73348981/958c889a-227e-4d0e-852c-ba277f764c7a)

To summarise the following is needed to check if appointments are available:
1. Make a GET request to the portal to get a session cookie (`/termine`).
3. Make a GET request to the specific page for a location (`/termine/select2?md=$id`).
4. Make a GET request in which we specify the request service using the url parameters (`/termine/location?mdt=$id&select_cnc=1&cnc-8580=0 ...`).
5. Make a POST request in which we specify the request service as using url parameters as well as some parameters in the request body (`/termine/location?mdt=$id&select_cnc=1&cnc-8580=0 ...`).
6. Make a final GET request to get the results (`/termine/suggest`).

Armed with this knowledge of how the portal works, I can now begin automating the appointment checking process.

## 2. Lambda function
Now, to automate the process, I will be using Python along with the `requests` library to make the needed GET and POST requests. 

To organise the Lambda functions, I will need to make a Lambda function for each City since the portals differ from city to city and as such, the process and code for checking the portals differs as well.

I called lambda function `lambda-anmeldung-jaeger-checkBremen`, it does the following in order:
1. Check all the locations in the Bremen portal using HTTPs requests.
2. Write the results as a JSON object to an S3 bucket called `anmeldung-jaeger.com` as `data.json`.
3. If any of location has available appointments, it publishes a message to the SNS topic for Bremen.
	- When publishing messages, it uses a message throttling system which only allows it to send on message every 20 minutes, this system uses a DynamoDB entry as a way to track when the last message was sent and act accordingly.

Here is a small snippet of the lambda function's event handler which summarises the previously described behaviour:
```python
def lambda_handler(event, context):
  
    bremen_list = data["Bremen"]

	# checking the portal for each location
    results = scrapeFunc.check_bremen(bremen_list)
    
    # writing the results to S3
    modify_s3_data_object(results)
     
    # sending a message if any of the locations have available appointments
    if any(item["status"] == "available" for item in results):
        
        print("DEBUG: Available appointments!")
        
        # Calculate the current time
        current_time = datetime.now()
        print(f"DEBUG: current_time={current_time}")
        
        if SEND_MESSAGE:
            # Check the DyanamoDB table for the last message timestamp
            last_message_time = get_last_message_time()

            # If more than the specified minutes have passed, publish a message to SNS

            if last_message_time is None or (current_time - last_message_time) >= timedelta(minutes=MESSAGE_THROTTLE_MINUTES):
                message = format_message(results) 
           
                send_sns_message(message)
                update_last_message_time(current_time)
            else: 
                print("DEBUG: SNS message throttled")
        else:
            print("DEBUG: SEND_MESSAGE is set to False")
        
    
    return results
```

To make this Lambda function run every 5 minutes, I used the *Amazon EventBridge Scheduler*.

I also had to give it the appropriate permissions via a role where I used *the principle of least privilege* to only grant it the bare minimum permissions that it needs:
- `logs:CreateLogStream` and `logs:PutLogEvents` to allow the function to be logged in *CloudWatch Logs*.
- `s3:PutObject` on `arn:aws:s3:::anmeldung-jaeger.com/data.json` to allow the function to modify the object.
- `dynamodb:GetItem` and `dynamoDB:PutItem` on the cache DynamoDB table to allow the function to read and write the cache table.
- `sns:Publish` on the SNS topic for Bremen to allow the function to publish messages.

To see the function's complete code check the GitHub repo link: *insert link*

## 3. S3
The results of the crawling Lambda function must be stored somewhere in order to be accessed later on. For this, I used an S3 bucket which contains the following:
- `data.json`: the file is being continuously updated by the Lambda function every time with the latest available appointments, the file looks like this:
```json
[
  {
    "location": "BürgerServiceCenter-Nord",
    "status": "available",
    "datetime": "25/12/2023 13:39:56",
    "days": [
      "Donnerstag, 18.04.2024",
      "Freitag, 19.04.2024"
    ]
  },
  {
    "location": "BürgerServiceCenter-Mitte",
    "status": "not available",
    "datetime": "25/12/2023 13:39:59",
    "days": []
  },
  {
    "location": "BürgerServiceCenter-Stresemannstraße",
    "status": "available",
    "datetime": "25/12/2023 13:40:01",
    "days": [
      "Donnerstag, 18.04.2024",
      "Freitag, 19.04.2024"
    ]
  }
]
```
## 4. Amazon API Gateway
Now that we have the `data.json` file being regularly updated by the Lambda function, we need a way to access it, that is where the REST API comes in.
I created an Amazon API Gateway REST API called `aj-api` that can fetch the results of `data.json` by running a lambda function called `aj-getData-lambda-function` which has access to the S3 bucket containing `data.json`.
The API has two method types: GET and OPTIONS. The OPTIONS method was added after enabling CORS.
CORS needs to be enabled since I will be calling this API from another domain in the frontend.

## 5. AWS Amplify
I used AWS Amplify to host a simple frontend website that will allow us to display which appointments are available in which locations.
The frontend code is stored in another GitHub repo (https://github.com/ilyasben26/aws-aj-front-end) which is connected to AWS Amplify, the repo contains a simple static html file along with some client-side javascript code that calls the `aj-api` to get `data.json` and then displays the ouput in a human readable fashion.
The website looks like this:

![Screenshot 2023-12-29 at 15-02-24 Anmeldung Jaeger](https://github.com/ilyasben26/aws-anmeldung-jaeger-terraform/assets/73348981/f0a5f3ec-a4ba-4df0-88cb-95d3d4490554)

## 6. Route 53
To make this whole operation more trustworthy and also give the German authorities a way to contact me in case the website unintentionally broke some laws, I bough the domain name `anmeldung-jaeger.com` for the meagre sum of $13 per year using Route 53.
I then configured this domain with AWS Amplify to access the frontend with it, it even comes with an SSL certificate for even more trustworthiness! You can now visit `https://anmeldung-jaeger.com` or `https://www.anmledung-jaeger.com` to see my website.

## 7. DevOps
To make it easier to improve this little project of mine, I used some handy DevOps practices like using Terraform and AWS Amplify along with a GitHub repo.
I mainly used Terraform to manage the lambda functions from VS Code.

# 4. Conclusion
Through this small project, I had the chance to apply some of the theoretical knowledge I acquired from studying for the *AWS Cloud Practitioner* certification and the *AWS Solutions Architect Associate* certification. I was able to keep costs to a minimum by using AWS's free tier, which allows up to 1 million Lambda requests for free per month. 

Currently the application can:
- Track the availability of Anmeldung appointments in Bremen.
- Send a message to my email in case free appointments are available.
- Display the availability of appointments all over Bremen in a website.

Future work-in progress functionalities:
- Tracking more cities.
- Allowing users to subscribe to a mailing list to receive a notification as soon as an appointment is available.
- Allowing users to create accounts.




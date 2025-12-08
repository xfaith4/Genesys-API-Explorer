# Template Catalog

Complete reference of all 31 pre-configured templates in the Genesys Cloud API Explorer.

## Overview

- **Total Templates**: 31
- **GET Templates**: 22 (71%)
- **POST Templates**: 9 (29%)
- **Categories**: 6

---

## Conversations (8 Templates)

All GET templates for retrieving conversation data and recordings.

### 1. Get Active Conversations
- **Method**: GET
- **Path**: `/api/v2/conversations`
- **Parameters**: None
- **Description**: Retrieve all active conversations for the logged-in user

### 2. Get Specific Conversation Details
- **Method**: GET
- **Path**: `/api/v2/conversations/{conversationId}`
- **Parameters**: `conversationId`
- **Description**: Fetch complete details for a single conversation

### 3. Get Conversation Recording Metadata
- **Method**: GET
- **Path**: `/api/v2/conversations/{conversationId}/recordingmetadata`
- **Parameters**: `conversationId`
- **Description**: Get recording metadata for a conversation (no playable media)

### 4. Get Call History
- **Method**: GET
- **Path**: `/api/v2/conversations/calls/history`
- **Parameters**: `pageSize`, `pageNumber`
- **Description**: Retrieve call history with pagination

### 5. Get Active Callbacks
- **Method**: GET
- **Path**: `/api/v2/conversations/callbacks`
- **Parameters**: None
- **Description**: List all currently active callbacks

### 6. Get Active Calls
- **Method**: GET
- **Path**: `/api/v2/conversations/calls`
- **Parameters**: None
- **Description**: List all currently active calls

### 7. Get Active Chats
- **Method**: GET
- **Path**: `/api/v2/conversations/chats`
- **Parameters**: None
- **Description**: List all currently active chat conversations

### 8. Get Active Emails
- **Method**: GET
- **Path**: `/api/v2/conversations/emails`
- **Parameters**: None
- **Description**: List all currently active email conversations

---

## Analytics (14 Templates)

5 GET templates and 9 POST templates for conversation analytics and queries.

### GET Templates

#### 9. Get Multiple Conversations by IDs
- **Method**: GET
- **Path**: `/api/v2/analytics/conversations/details`
- **Parameters**: `id` (comma-separated)
- **Description**: Batch retrieval of multiple conversations

#### 10. Get Single Conversation Analytics
- **Method**: GET
- **Path**: `/api/v2/analytics/conversations/{conversationId}/details`
- **Parameters**: `conversationId`
- **Description**: Get detailed analytics for one conversation

#### 11. Get Conversation Details Job Status
- **Method**: GET
- **Path**: `/api/v2/analytics/conversations/details/jobs/{jobId}`
- **Parameters**: `jobId`
- **Description**: Check the status of an async conversation query job

#### 12. Get Conversation Details Job Results
- **Method**: GET
- **Path**: `/api/v2/analytics/conversations/details/jobs/{jobId}/results`
- **Parameters**: `jobId`, `pageSize`
- **Description**: Retrieve results from a completed async job

#### 13. Get User Details Job Status
- **Method**: GET
- **Path**: `/api/v2/analytics/users/details/jobs/{jobId}`
- **Parameters**: `jobId`
- **Description**: Check the status of an async user details query job

### POST Templates

#### 14. Query Conversation Details - Last 7 Days
- **Method**: POST
- **Path**: `/api/v2/analytics/conversations/details/query`
- **Parameters**: `body` (JSON with interval, paging, filters)
- **Description**: Fetch detailed conversation data for the past week

#### 15. Query Conversation Details - Today
- **Method**: POST
- **Path**: `/api/v2/analytics/conversations/details/query`
- **Parameters**: `body` (JSON with interval, paging, filters)
- **Description**: Get today's conversation details with recent-first ordering

#### 16. Query Conversation Details - By Queue
- **Method**: POST
- **Path**: `/api/v2/analytics/conversations/details/query`
- **Parameters**: `body` (JSON with queue filter)
- **Description**: Filter conversations by specific queue ID

#### 17. Query Conversation Details - By Media Type
- **Method**: POST
- **Path**: `/api/v2/analytics/conversations/details/query`
- **Parameters**: `body` (JSON with media type filter)
- **Description**: Filter conversations by media type (voice, chat, email, etc.)

#### 18. Query Conversation Aggregates - Daily Stats
- **Method**: POST
- **Path**: `/api/v2/analytics/conversations/aggregates/query`
- **Parameters**: `body` (JSON with interval, groupBy, metrics)
- **Description**: Get aggregated metrics by hour and queue

#### 19. Query Conversation Aggregates - Agent Performance
- **Method**: POST
- **Path**: `/api/v2/analytics/conversations/aggregates/query`
- **Parameters**: `body` (JSON with groupBy userId, metrics)
- **Description**: Analyze agent performance metrics by user

#### 20. Query Conversation Transcripts
- **Method**: POST
- **Path**: `/api/v2/analytics/conversations/transcripts/query`
- **Parameters**: `body` (JSON with conversation filters)
- **Description**: Retrieve conversation transcripts for analysis

#### 21. Create Conversation Details Job - Large Query
- **Method**: POST
- **Path**: `/api/v2/analytics/conversations/details/jobs`
- **Parameters**: `body` (JSON with interval, filters)
- **Description**: Initiate an async job for large data queries

#### 22. Query Conversation Activity
- **Method**: POST
- **Path**: `/api/v2/analytics/conversations/activity/query`
- **Parameters**: `body` (JSON with interval, filter, metrics)
- **Description**: Get real-time conversation activity metrics

---

## Speech and Text Analytics (2 Templates)

All GET templates for speech analytics and sentiment analysis.

### 23. Get Speech and Text Analytics for Conversation
- **Method**: GET
- **Path**: `/api/v2/speechandtextanalytics/conversations/{conversationId}`
- **Parameters**: `conversationId`
- **Description**: Get comprehensive speech analytics for a conversation

### 24. Get Sentiment Data for Conversation
- **Method**: GET
- **Path**: `/api/v2/speechandtextanalytics/conversations/{conversationId}/sentiments`
- **Parameters**: `conversationId`
- **Description**: Retrieve sentiment analysis data for a conversation

---

## Telephony (1 Template)

GET template for telephony troubleshooting.

### 25. Get SIP Message for Conversation
- **Method**: GET
- **Path**: `/api/v2/telephony/sipmessages/conversations/{conversationId}`
- **Parameters**: `conversationId`
- **Description**: Get the raw SIP message for a conversation

---

## Routing (2 Templates)

All GET templates for routing and queue management.

### 26. Get Queue Details
- **Method**: GET
- **Path**: `/api/v2/routing/queues/{queueId}`
- **Parameters**: `queueId`
- **Description**: Get detailed information about a specific queue

### 27. Get Queue Members
- **Method**: GET
- **Path**: `/api/v2/routing/queues/{queueId}/members`
- **Parameters**: `queueId`
- **Description**: List all members assigned to a queue

---

## Users (4 Templates)

All GET templates for user routing, skills, and presence.

### 28. Get User Routing Skills
- **Method**: GET
- **Path**: `/api/v2/users/{userId}/routingskills`
- **Parameters**: `userId`
- **Description**: List routing skills assigned to a user

### 29. Get User Presence (Genesys Cloud)
- **Method**: GET
- **Path**: `/api/v2/users/{userId}/presences/purecloud`
- **Parameters**: `userId`
- **Description**: Get a user's Genesys Cloud presence status

### 30. Get Bulk User Presences (Genesys Cloud)
- **Method**: GET
- **Path**: `/api/v2/users/presences/purecloud/bulk`
- **Parameters**: `id` (comma-separated user IDs)
- **Description**: Get presence status for multiple users at once

### 31. Get User Routing Status
- **Method**: GET
- **Path**: `/api/v2/users/{userId}/routingstatus`
- **Parameters**: `userId`
- **Description**: Fetch the routing status of a user

---

## Usage Notes

### Placeholder Parameters

Many templates use placeholder values that must be replaced:
- `conversation-id-goes-here` - Replace with actual conversation ID
- `queue-id-goes-here` - Replace with actual queue ID
- `user-id-goes-here` - Replace with actual user ID
- `job-id-goes-here` - Replace with actual job ID

### Date Ranges

POST templates with date ranges use example dates:
- Update `interval` fields to your desired date range
- Format: `YYYY-MM-DDTHH:mm:ss.sssZ/YYYY-MM-DDTHH:mm:ss.sssZ`

### Comma-Separated Lists

Some templates accept multiple IDs:
- `id` parameter: `user-id-1,user-id-2,user-id-3`
- Replace with actual IDs separated by commas

---

## Template Categories by Use Case

### Real-Time Monitoring
- Get Active Conversations
- Get Active Callbacks/Calls/Chats/Emails
- Get User Presence
- Get Bulk User Presences
- Get User Routing Status

### Historical Analysis
- Get Call History
- Query Conversation Details (all variants)
- Query Conversation Aggregates
- Query Conversation Activity

### Deep Analysis
- Get Single Conversation Analytics
- Get Speech and Text Analytics
- Get Sentiment Data
- Query Conversation Transcripts

### Troubleshooting
- Get SIP Message for Conversation
- Get Conversation Recording Metadata
- Get Speech and Text Analytics

### Configuration & Staffing
- Get Queue Details
- Get Queue Members
- Get User Routing Skills

### Bulk Operations
- Create Conversation Details Job
- Get Conversation Details Job Status/Results
- Get User Details Job Status
- Get Multiple Conversations by IDs
- Get Bulk User Presences

---

## Template Groups

| Category | GET | POST | Total | % |
|----------|-----|------|-------|---|
| Conversations | 8 | 0 | 8 | 25.8% |
| Analytics | 5 | 9 | 14 | 45.2% |
| Speech and Text Analytics | 2 | 0 | 2 | 6.5% |
| Telephony | 1 | 0 | 1 | 3.2% |
| Routing | 2 | 0 | 2 | 6.5% |
| Users | 4 | 0 | 4 | 12.9% |
| **Total** | **22** | **9** | **31** | **100%** |

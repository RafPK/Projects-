# Review Intelligence Privacy and Client-Data Guidance

Review data can contain personal information, employee names, order details, location information, or other customer-specific content. A commercial deployment should therefore treat review datasets as client data rather than ordinary demo files.

## Public repository rule

**Do not commit real client review exports to this public repository.**

The portfolio repository should contain documentation, synthetic/sample data, screenshots with safe content, and code that does not embed customer records.

## Local/private service model

The current architecture can support a privacy-conscious service because the Python analysis can run locally or inside a customer-controlled environment.

Recommended workflow:

```text
Customer data
   ↓
Private approved storage
   ↓
Local/private analysis
   ↓
Dashboard/output
   ↓
Agreed retention period
   ↓
Delete or archive according to agreement
```

## Minimum client-data practices

Before handling paid customer data:

- define where files will be stored;
- limit access to only the people who need it;
- avoid copying datasets into public repositories or issue trackers;
- minimize unnecessary personal information;
- agree on retention and deletion expectations;
- encrypt devices/storage where appropriate;
- do not log full review text unless required for debugging;
- keep credentials and tokens out of source control;
- document how customers can request deletion of their files.

## Hosted-product requirements

A future SaaS version should add:

- authenticated accounts;
- tenant isolation;
- secure uploads;
- encrypted storage and transport;
- access controls;
- auditability;
- deletion/export controls;
- retention policies;
- incident-response procedures;
- privacy terms appropriate to the markets served.

## Public inquiries

GitHub issues are public. Potential customers should describe their use case and approximate review volume only. They should **not** paste or attach confidential review data.

## Scope

This file is an engineering/privacy checklist for the project, not legal advice. Commercial deployment should be reviewed against the laws, contracts, and platform terms relevant to the customer and jurisdiction.

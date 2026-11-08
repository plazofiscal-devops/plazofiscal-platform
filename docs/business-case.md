# Business case

PlazoFiscal is a software service that helps small accounting firms in Colombia track the tax obligations of their clients. This document explains the company, the problem it solves, how demand behaves through the year, and what the platform must guarantee. Every company fact and figure here is invented for an academic exercise. Filing dates are a simplified model of a real calendar that changes each year.

## Contents

1. Terms
2. The company
3. The problem
4. Who uses the product
5. What the product does
6. How demand behaves
7. Service objectives
8. Business indicators
9. Risks
10. Assumptions

## 1. Terms

| Term | Meaning |
|---|---|
| Obligation | A tax filing or payment that a client must complete by a date |
| Filing window | The days when most obligations of a period fall due |
| Firm | An accounting office that serves several client companies |
| Service objective | A measurable promise about how the service behaves |

## 2. The company

PlazoFiscal is a young company with a small engineering team, and it sells a monthly subscription per firm. It has no operations department, so the DevOps engineers own the platform, its reliability and its cost.

## 3. The problem

A small firm may serve dozens of companies, each with its own calendar. Withholding, value added tax and income tax fall due on different dates, which depend on the tax identification number of each client. Many firms still track this in spreadsheets. A missed date brings a penalty for the client and a lost customer for the firm.

The risk peaks exactly when the firm is busiest. For that reason, the product has the most value on the days when its load is highest, and an outage during a filing window costs more than at any other moment.

## 4. Who uses the product

| User | Needs |
|---|---|
| Accountant | The list of obligations due, and marking each one as done |
| Firm manager | Whether any obligation of any client is at risk |
| PlazoFiscal operator | The health and the cost of the platform |

## 5. What the product does

| Service | Business role |
|---|---|
| Frontend | The screen where accountants work |
| Sign-in and users | Identity of each accountant |
| Obligations, the `todos-api` service | Creating, listing and closing obligations |
| Activity processor | Recording each change, as a trail of who did what |

An obligation records the client, the tax, the due date and an optional note. The taxes covered are value added tax, withholding at source, income tax and the municipal industry and commerce tax. The main screen lists pending obligations by due date, marks the overdue ones and those due within seven days, filters by tax or by day on a calendar, and counts overdue, due this week and pending obligations. When an accountant marks an obligation as presented, it leaves the list, and the activity processor keeps the record of who closed it and when. The screen is in Spanish, the language of the firms.

## 6. How demand behaves

| Period | Dates | Expected load | Platform response |
|---|---|---|---|
| Normal | Days 1 to 7 and 25 to 31 of a month | About 5 requests a second | Minimum replicas |
| Monthly filing window | Days 8 to 24 | About 15 requests a second | Two replicas from the morning of day 8 |
| Income tax season | August to October | About 30 requests a second at peak | Maximum replicas from the morning of 1 August |
| Night | Any day | Near zero | Load based scaling returns to the minimum |

The calendar raises capacity before the peak, and CPU load reacts to what the calendar cannot predict. Both rules run in the America/Bogota time zone. Capacity stays inside the cluster limit, so replicas have fixed maximums.

## 7. Service objectives

| Objective | Target | Why it matters |
|---|---|---|
| Availability in a filing window | 99.5 percent of requests succeed | A failure on these days can cost a client a penalty |
| Response time | 95 percent of requests under 500 ms | Accountants work through long lists |
| Deployment | No failed requests during a rolling update | Releases cannot wait for a quiet month |

## 8. Business indicators

The dashboard shows these indicators next to the technical signals, so that a manager can read the state of the business without knowing the platform.

| Indicator | Question it answers |
|---|---|
| Obligations closed per hour | Is work advancing? |
| Failed sign-ins | Is someone having trouble, or trying to get in? |
| Cost per day and per service | What does the platform cost to run? |
| Days until the next filing window | Should a release wait? |

## 9. Risks

| Risk | Effect | Response |
|---|---|---|
| A release fails during a filing window | Accountants cannot work | Rolling update keeps old pods until new ones are ready, and an undo returns to the previous version |
| Load exceeds the cluster | Slow responses | Maximum replicas protect the rest of the platform, and an alert warns the operator |
| Unauthorized access | Exposure of client data | Sign-in with a second factor, and network isolation between services |
| Redis loses its pod | Short interruption | Data stays on the persistent volume, and the pod returns on its own |
| Cost grows unnoticed | Margin erodes | Kubecost shows cost per service, and an alert warns about idle capacity |

## 10. Assumptions

| Assumption | Who confirms | What changes if it fails |
|---|---|---|
| Load figures per period | First customers | Scaling limits and cluster size |
| Filing dates of the model | Current tax calendar | Dates of the scaling rules |
| The monthly window spans days 8 to 24 | Current tax calendar | One rule of the calendar |

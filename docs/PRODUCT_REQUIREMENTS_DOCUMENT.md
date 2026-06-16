# Meatvo — Product Requirements Document (PRD)

**Version:** 1.0  
**Date:** June 12, 2026  
**Document Owner:** Chief Product Officer  
**Classification:** Confidential — Investor & Internal Use

---

## Document Information

| Attribute | Value |
|-----------|-------|
| **Product Name** | Meatvo |
| **Product Type** | Hyperlocal Fresh Meat & Grocery Delivery Platform |
| **Target Launch** | Q3 2026 (MVP) |
| **Platform** | iOS, Android (Flutter), Web (Admin Dashboard) |
| **Target Market** | Urban India (Tier 1 & 2 cities) |
| **Business Model** | B2C Marketplace with Owned Inventory |

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product Vision](#2-product-vision)
3. [Business Objectives](#3-business-objectives)
4. [Target Market](#4-target-market)
5. [Customer Personas](#5-customer-personas)
6. [Competitive Analysis](#6-competitive-analysis)
7. [User Roles](#7-user-roles)
8. [Customer Journey](#8-customer-journey)
9. [Functional Requirements](#9-functional-requirements)
10. [Non-Functional Requirements](#10-non-functional-requirements)
11. [Success Metrics](#11-success-metrics)
12. [Key Performance Indicators (KPIs)](#12-key-performance-indicators)
13. [Revenue Model](#13-revenue-model)
14. [Risk Analysis](#14-risk-analysis)
15. [MVP Scope](#15-mvp-scope)
16. [Future Roadmap](#16-future-roadmap)

---

## 1. Executive Summary

### 1.1 Product Overview

**Meatvo** is a hyperlocal fresh meat and grocery delivery platform that combines **Licious's quality-first approach** with **Zepto's speed-to-delivery model** to deliver farm-fresh, hygienically processed chicken, mutton, fish, eggs, and groceries to urban households within **30 minutes**.

### 1.2 Problem Statement

**Current Pain Points in the Market:**

1. **Traditional Butchers:**
   - Hygiene concerns (open-air cutting, no cold chain)
   - No traceability (unknown sourcing)
   - Inconsistent quality and pricing
   - Limited operating hours (closed by evening)

2. **Existing Online Players (Licious, FreshToHome):**
   - Slow delivery (24-hour pre-order, next-day delivery)
   - High minimum order values
   - Limited impulse purchase opportunities
   - Premium pricing (30-40% higher than local markets)

3. **Quick Commerce (Zepto, Blinkit):**
   - Limited meat selection (pre-packaged only)
   - No specialized cold chain
   - Quality concerns (shelf-life optimization over freshness)
   - No meat expertise (generalist approach)

### 1.3 Solution

Meatvo bridges the gap by offering:

- ✅ **30-Minute Delivery:** Hyperlocal dark stores (2-3 km radius)
- ✅ **Quality Assurance:** FSSAI-certified processing, farm-to-fork traceability
- ✅ **Competitive Pricing:** 15-20% cheaper than Licious, on-par with quality local butchers
- ✅ **Curated Selection:** 100+ SKUs (chicken, mutton, fish, eggs, marinades)
- ✅ **Transparent Sourcing:** QR code tracking, temperature-logged cold chain
- ✅ **Flexible Payment:** COD + Online (Razorpay UPI/cards/wallets)

### 1.4 Market Opportunity

**Target City: Bokaro Steel City, Jharkhand**

| Metric | Value |
|--------|-------|
| **City Population** | 5.5 Lakh (550,000) |
| **Target Households** | ~1 Lakh households |
| **Online-Ready Households** | ~20,000 (20% penetration) |
| **Initial Service Area** | 5-10 km radius from store |
| **Serviceable Households (Phase 1)** | ~5,000 households |
| **Target Market Size** | ₹50-75 Cr annual (local meat market) |

### 1.5 Business Model

**Primary Revenue Streams:**
1. **Product Sales (95%):** Direct revenue from meat, seafood, eggs, groceries
2. **Delivery Fees (5%):** ₹20-40 per order (based on distance within 5-10km radius)
3. **Subscription (Future):** "Meatvo Prime" planned for Phase 2

**Unit Economics (Bokaro Steel City):**
```
Average Order Value (AOV):           ₹650-700
Gross Margin:                        35% (₹228-245)
Contribution Margin:                 28-30% (₹182-210)
Customer Acquisition Cost (CAC):     ₹120-150 (local marketing)
Lifetime Value (LTV):                ₹2,800-3,500 (8-10 orders over 6 months)
LTV:CAC Ratio:                       20-23x (healthy: >3x)
Payback Period:                      1.5-2 months
```

### 1.6 Competitive Advantage

1. **Speed:** 30 min vs. 24 hours (Licious) — captures impulse purchases
2. **Price:** 15-20% cheaper than premium competitors
3. **Quality:** FSSAI-certified, farm-to-fork traceability (QR codes)
4. **Tech:** AI demand forecasting (40% waste reduction), real-time tracking
5. **Asset-Light:** Dark stores (rental) vs. owned infrastructure — faster expansion

---

## 2. Product Vision

### 2.1 Vision Statement

> "To become India's most trusted platform for fresh, hygienic, and traceable meat delivery, making premium-quality protein accessible to every urban household within 30 minutes."

### 2.2 Mission Statement

> "Deliver farm-fresh, hygienically processed meat and groceries to urban households with unprecedented speed, transparency, and quality assurance, while empowering local farmers and creating livelihood opportunities."

### 2.3 Product Principles

1. **Quality First:** Never compromise on hygiene, freshness, or traceability
2. **Speed Matters:** 30-minute delivery is a core promise, not a nice-to-have
3. **Transparent by Default:** Show sourcing, processing, nutrition, cold chain logs
4. **Customer Obsessed:** Every decision optimized for customer convenience
5. **Sustainable Growth:** Profitable unit economics, ethical sourcing, minimal waste

### 2.4 Long-Term Vision (3-5 Years)

**Year 1:** Establish dominance in Bokaro Steel City (5,000-8,000 MAU, 1 store)  
**Year 2:** Expand to 2-3 stores in Bokaro, cover 15-20km radius (15,000-20,000 MAU)  
**Year 3:** Expand to nearby cities (Dhanbad, Ranchi) if Bokaro proves successful  
**Year 4-5:** Regional dominance in Jharkhand, expand to Bihar cities if profitable

### 2.5 Brand Positioning

**Tagline:** *"Fresh. Fast. Fearless."*

**Brand Attributes:**
- **Premium yet Accessible:** High quality at competitive prices
- **Trustworthy:** Transparent sourcing, FSSAI-certified, temperature-logged
- **Modern:** Tech-driven, app-first, instant gratification
- **Relatable:** Understands Indian cooking needs (curry cuts, marination options)

**Brand Voice:**
- Confident, knowledgeable (meat expertise)
- Warm, approachable (not elitist)
- Educational (recipes, nutrition, cooking tips)
- Transparent (honest about sourcing, pricing)

---

## 3. Business Objectives

### 3.1 Strategic Objectives (36 Months)

#### Phase 1: Launch & Validate (Months 1-6)
**Goal:** Prove product-market fit in Bokaro Steel City (5-10km radius)

| Objective | Target | Success Criteria |
|-----------|--------|------------------|
| Launch MVP | Q3 2026 | Fully functional Android app + backend (iOS optional) |
| Service Area | 5-10 km radius | Cover major areas: Sector 1-12, City Centre, Chas |
| User Acquisition | 3,000-5,000 MAU | Strong local presence |
| Order Volume | 2,000-3,000 orders/month | 0.6-0.8 orders per active user/month |
| Repeat Rate | 35-40% | Strong retention in local community |
| NPS | 65+ | Strong word-of-mouth (critical for local market) |
| Unit Economics | Contribution margin >0% | Positive CM per order |

#### Phase 2: Scale & Optimize (Months 7-18)
**Goal:** Expand coverage in Bokaro Steel City + adjacent areas

| Objective | Target | Success Criteria |
|-----------|--------|------------------|
| Geographic Expansion | 2-3 stores in Bokaro | Cover 15-20 km radius total |
| Service Areas | Expand to Gomia, Chandrapura | Adjacent localities |
| User Acquisition | 12,000-15,000 MAU | 3-4x growth from Phase 1 |
| Order Volume | 8,000-10,000 orders/month | 3-4x growth |
| Repeat Rate | 50-55% | Strong retention |
| NPS | 70+ | Excellent local reputation |
| Unit Economics | Positive EBITDA | Break-even or profitable |
| Fundraising | Bootstrap or ₹50-75 Lakh angel | Self-sustaining or minimal funding |

#### Phase 3: Regional Expansion (Months 19-36)
**Goal:** Expand to nearby cities if Bokaro is profitable

| Objective | Target | Success Criteria |
|-----------|--------|------------------|
| Geographic Expansion | Dhanbad, Ranchi (if profitable) | 2-3 cities in Jharkhand |
| User Acquisition | 30,000-40,000 MAU (across 3 cities) | Steady growth |
| Order Volume | 20,000-25,000 orders/month | Sustainable scale |
| Repeat Rate | 55-60% | Strong retention across cities |
| NPS | 70-75 | Regional brand trust |
| Revenue | ₹15-20 Cr GMV/year | Profitable regional business |
| Profitability | 10-15% EBITDA margin | Sustainable, profitable growth |

### 3.2 Financial Objectives

**Year 1 Targets (Bokaro Only):**
- GMV: ₹1.5-2 Cr
- Revenue: ₹1.6-2.1 Cr (including delivery fees)
- Contribution Margin: 28-30%
- Monthly Burn: ₹3-4 Lakh (very lean operations)
- Cash Runway: Bootstrap or 12-15 months with ₹50L funding

**Year 3 Targets (Bokaro + 2 cities):**
- GMV: ₹15-20 Cr
- Revenue: ₹16-21 Cr
- EBITDA: +10-15% (profitable)
- Funding: Self-sustaining or small growth capital
- Valuation: ₹10-15 Cr (profitable regional business)

### 3.3 Product Objectives

1. **Customer Experience:**
   - App rating: 4.5+ stars (iOS/Android)
   - Order accuracy: >98%
   - On-time delivery: >92%
   - Customer support response: <5 minutes

2. **Operational Excellence:**
   - 30-minute delivery: >90% of orders
   - Product freshness: 0% complaints
   - Cold chain integrity: 100% temperature-logged
   - Rider utilization: >75%

3. **Technology:**
   - App crash rate: <0.1%
   - API response time: <200ms (P95)
   - System uptime: 99.9%
   - Real-time tracking: 100% of orders

---

## 4. Target Market

### 4.1 Market Segmentation

#### Geographic Segmentation

**Phase 1 (Launch): Bokaro Steel City, Jharkhand**
- **Primary Areas (5-10 km radius):**
  - Sector 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
  - City Centre, Chas, Sector 4 Market Area
- **Rationale:** 
  - Steel city with stable employment (SAIL workers)
  - Middle-class population with disposable income
  - Limited organized meat retail (gap in market)
  - Strong local community (word-of-mouth works well)

**Phase 2 (Expansion within Bokaro):**
- **Secondary Areas (10-20 km radius):**
  - Gomia, Chandrapura, Jaridih, Phusro
  - Industrial Township areas
- **Rationale:** Adjacent areas, similar demographics, expand coverage

**Phase 3 (Regional Expansion - if Bokaro profitable):**
- **Nearby Cities:** Dhanbad (85 km), Ranchi (100 km)
- **Rationale:** Replicate Bokaro model in similar tier-2/3 cities

#### Demographic Segmentation (Bokaro-Specific)

**Primary Target:**
- **Age:** 28-45 years
- **Income:** ₹30K-80K per month (middle class, SAIL employees, govt workers)
- **Household Size:** 3-5 members (nuclear + some joint families)
- **Occupation:** SAIL employees, bank employees, teachers, small business owners
- **Education:** Graduate+, comfortable with smartphones

**Secondary Target:**
- **Age:** 45-60 years
- **Income:** ₹50K-1.5L per month (senior officers, established businesses)
- **Household Size:** 4-6 members (joint families common in Bokaro)
- **Occupation:** Senior SAIL officers, doctors, contractors
- **Education:** Well-educated, value quality and convenience

#### Psychographic Segmentation

**Customer Mindset:**
- Health-conscious (high-protein diet, fitness enthusiasts)
- Time-starved (no time for market visits)
- Quality-conscious (willing to pay for hygiene, freshness)
- Tech-savvy (comfortable with app-based shopping)
- Convenience-seeking (values instant gratification)

**Lifestyle:**
- Urban, fast-paced lifestyle
- Regular meat consumers (3-4 times per week)
- Apartment dwellers (no access to traditional markets)
- Nuclear families (meal planning for 3-4 people)

### 4.2 Market Size & Opportunity (Bokaro Steel City)

#### Local Market Analysis

**Bokaro Steel City Demographics:**
- Population: 5.5 Lakh (550,000)
- Households: ~1 Lakh
- Average Household Income: ₹35-50K/month
- Meat-consuming households: ~60-70% (urban, non-vegetarian population)
- Online-ready households: ~20,000 (smartphone, comfortable with apps)

**Local Meat Market:**
- Total market size: ₹50-75 Cr/year (estimated)
- Current retail: 90% traditional butchers, 10% supermarkets
- Online penetration: <1% (huge opportunity)
- Average household meat spend: ₹2,000-3,000/month

#### Serviceable Market (Phase 1: 5-10km radius)

**Serviceable Households:**
- Within 5-10 km: ~30,000 households
- Online-ready: ~5,000-8,000 households
- Target capture: 30-40% (1,500-3,000 active users)

**Market Opportunity:**
- TAM (Bokaro): ₹50-75 Cr/year
- SAM (Online-ready, 5-10km): ₹5-8 Cr/year
- SOM (Year 1, 10% penetration): ₹50-80 Lakh/year
- SOM (Year 3, 30% penetration, expanded area): ₹5-7 Cr/year

### 4.3 Market Trends

**Favorable Trends:**

1. **Digital Adoption:** 700M+ internet users, 500M+ smartphone users
2. **E-Commerce Growth:** Online grocery penetration 5% → 20% (next 5 years)
3. **Quick Commerce Boom:** Zepto, Blinkit, Swiggy Instamart proving 10-30 min delivery viable
4. **Health & Wellness:** Protein consumption up 40% (fitness, nutrition awareness)
5. **Cold Chain Infrastructure:** Government investment in food logistics

**Challenges:**
1. **Price Sensitivity:** Indian consumers highly price-conscious
2. **Trust Deficit:** Online meat purchase hesitancy (quality concerns)
3. **Fragmented Market:** 80% of meat still sold by unorganized butchers
4. **Cultural Preferences:** Regional variations (chicken in South, mutton in North)
5. **Regulatory:** FSSAI compliance, local municipal regulations

---

## 5. Customer Personas

### 5.1 Persona 1: SAIL Employee Family (Primary)

**Name:** Amit Kumar  
**Age:** 35  
**Occupation:** Engineer at SAIL Bokaro  
**Location:** Sector 4, Bokaro Steel City  
**Income:** ₹55K/month  
**Family:** Married, 2 children (8 & 12 years)

**Profile:**
- Works 8-hour shifts at SAIL plant, reaches home by 6:30 PM
- Wife cooks at home daily (traditional North Indian/Bengali meals)
- Buys groceries from City Centre market weekly
- Health-conscious (wants clean, hygienic meat for kids)
- Uses UPI for most payments, comfortable with apps

**Pain Points:**
- Local butcher shop 2 km away (no parking, crowded)
- Weekend market visit takes 1-2 hours (long queues)
- Hygiene concerns (open-air cutting, flies in summer)
- Quality inconsistent (especially fish)
- Wife complains about spending Saturdays at market

**Goals:**
- Buy fresh meat without weekend market trips
- Hygienic, FSSAI-approved meat for family
- Home delivery (save time, avoid crowds)
- Reasonable pricing (₹20-30 extra okay for convenience)
- Trusted source (important for children's health)

**How Meatvo Solves:**
- ✅ Home delivery in 30-45 minutes (order evening, get by dinner)
- ✅ FSSAI-certified, temperature-controlled packaging
- ✅ Clean cutting, no flies or contamination
- ✅ Similar pricing to good local butchers + small delivery fee
- ✅ Easy reorder (same items every week)

**Tech Behavior:**
- Smartphone: Samsung Galaxy M32 (Android user)
- Apps Used: PhonePe, WhatsApp, JioMart, Swiggy occasionally
- Social Media: Facebook, WhatsApp groups (SAIL colony groups)
- Payment: UPI (PhonePe) 70%, COD 30%

**Quote:**  
*"Agar ghar pe fresh chicken mil jaye aur hygiene bhi theek ho, toh weekend ka market jaane ka jhanjhat bach jaye. SAIL colony mein sabko bataunga."*  
*(If I can get fresh chicken at home with good hygiene, I can avoid weekend market hassles. I'll tell everyone in SAIL colony.)*

---

### 5.2 Persona 2: Health-Conscious Parent (Primary)

**Name:** Rajesh Iyer  
**Age:** 38  
**Occupation:** Marketing Manager at TCS  
**Location:** Koramangala, Bangalore  
**Income:** ₹1.8L/month  
**Family:** Married, 2 children (8 & 12 years)

**Profile:**
- Pescatarian household (fish, eggs, no red meat)
- Cooks at home daily (wife is homemaker, prioritizes nutrition)
- Concerned about children's growth (protein-rich diet)
- Orders Licious 1x/week (finds it expensive, but trusts quality)
- Values transparency (reads labels, researches brands)

**Pain Points:**
- Licious too expensive for weekly consumption (₹800-1000 per order)
- Local fish market 3 km away (time-consuming, parking hassle)
- Quality inconsistency (fish freshness varies)
- No nutritional information on local market fish
- Delivery slots limited (Licious only 10 AM-2 PM, wife busy with kids)

**Goals:**
- Affordable, fresh fish for family (3-4x/week)
- Nutritional transparency (calories, protein, omega-3)
- Flexible delivery (evening slots when kids are at school)
- Build trust with a single brand (reduce decision fatigue)

**How Meatvo Solves:**
- ✅ 20% cheaper than Licious (₹600-700 for similar order)
- ✅ Nutritional info displayed (calories, protein per 100g)
- ✅ Evening delivery slots (6-8 PM)
- ✅ QR code sourcing (coastal Kerala, catch date)
- ✅ Subscribe & Save (₹299/month Meatvo Prime, free delivery)

**Tech Behavior:**
- Smartphone: Samsung Galaxy S22 (Android app user)
- Apps Used: Amazon, Swiggy, Licious, Healthifyme
- Social Media: Facebook, YouTube (watches recipe videos)
- Payment: UPI (Paytm) 60%, card 40%

**Quote:**  
*"I want my kids to have fresh fish 3 times a week, but Licious is too expensive. If Meatvo offers the same quality at 20% less, I'll switch immediately."*

---

### 5.3 Persona 3: Busy Entrepreneur (Secondary)

**Name:** Karan Mehta  
**Age:** 29  
**Occupation:** Founder of SaaS Startup  
**Location:** Indiranagar, Bangalore  
**Income:** ₹2.5L/month (variable)  
**Family:** Single, lives alone

**Profile:**
- Works 12-14 hour days (startup grind)
- Orders food online 80% of the time (Swiggy, Zomato)
- Cooks 2-3x/week (Sunday meal prep, weeknight quick dinners)
- Fitness enthusiast (keto diet, high protein, low carb)
- Early adopter (tries new apps, tech products)

**Pain Points:**
- No time for grocery shopping (weekends consumed by work)
- Restaurants expensive for daily meals (₹400-600 per order)
- Needs meal prep flexibility (batch cook chicken on Sundays)
- Licious requires planning (can't spontaneously decide to cook)
- Quality uncertainty with Swiggy Instamart meat

**Goals:**
- On-demand meat delivery for spontaneous cooking
- High-quality protein (boneless chicken breast, fish)
- Fast delivery (within 30 min, no meal planning required)
- Subscription model (set-and-forget, weekly delivery)

**How Meatvo Solves:**
- ✅ 30-minute delivery (spontaneous cooking possible)
- ✅ Meatvo Prime subscription (weekly auto-delivery, ₹299/month)
- ✅ Keto-friendly filters (low carb, high protein products)
- ✅ Bulk packs (1kg chicken breast for meal prep)
- ✅ Pre-marinated options (saves prep time)

**Tech Behavior:**
- Smartphone: iPhone 14 Pro (iOS app power user)
- Apps Used: Swiggy, Zomato, Zepto, Dunzo, Uber, Notion
- Social Media: Twitter, Instagram (follows fitness influencers)
- Payment: Credit card (rewards), UPI

**Quote:**  
*"I decide to cook at 9 PM after work. If Meatvo can deliver fresh chicken breast in 30 minutes, they own my wallet. No more planning meals 24 hours in advance."*

---

### 5.4 Persona 4: Traditional Homemaker (Secondary)

**Name:** Lakshmi Devi  
**Age:** 52  
**Occupation:** Homemaker  
**Location:** Jayanagar, Bangalore  
**Income:** Household ₹2L/month (husband is doctor)  
**Family:** Married, 2 adult children (living away)

**Profile:**
- Cooks elaborate meals daily (traditional South Indian, North Indian)
- Values quality and freshness (morning market visits 3x/week)
- Skeptical of online purchases (prefers to see/touch products)
- Introduced to apps by children (uses WhatsApp, YouTube)
- Cash preference (slowly adopting UPI via children's guidance)

**Pain Points:**
- Market visits time-consuming (1-2 hours)
- Heavy to carry (mutton, chicken, groceries)
- Trust issues with online meat (can't inspect quality)
- Husband suggests online ordering (convenience for her)
- Prices fluctuate (no transparency at market)

**Goals:**
- Reduce market visit burden (physical strain)
- Maintain quality standards (no compromise)
- Transparent pricing (no haggling)
- COD option (prefers cash, slowly learning UPI)

**How Meatvo Solves:**
- ✅ COD available (cash acceptance for trust-building)
- ✅ Product images (see before buying)
- ✅ Fixed pricing (no haggling, transparent)
- ✅ FSSAI certification (government-approved trust signal)
- ✅ Simple app UX (large fonts, vernacular support - roadmap)

**Tech Behavior:**
- Smartphone: Basic Android (Redmi Note 10)
- Apps Used: WhatsApp, YouTube, Paytm (via children's help)
- Social Media: WhatsApp groups (family, neighborhood)
- Payment: COD 70%, UPI (Paytm) 30%

**Quote:**  
*"I've been buying meat from the same butcher for 20 years. If Meatvo can match his quality and let me pay cash, I'll try once. If good, I'll tell my WhatsApp group."*

---

## 6. Competitive Analysis

### 6.1 Direct Competitors

#### Competitor 1: Licious

**Overview:**
- Founded: 2015
- Funding: $200M+ (Series G)
- Presence: 15 cities
- Customers: 2M+

**Strengths:**
- ✅ Strong brand (trust, quality)
- ✅ Wide product range (300+ SKUs)
- ✅ Own processing units (quality control)
- ✅ Packaging excellence (vacuum-sealed, premium)
- ✅ Subscription model (daily/weekly deliveries)

**Weaknesses:**
- ❌ Slow delivery (24-hour pre-order, next-day)
- ❌ Premium pricing (30-40% above market)
- ❌ High minimum order value (₹500+)
- ❌ No impulse purchase (planning required)
- ❌ Limited delivery slots (10 AM-2 PM)

**Positioning:** Premium quality, next-day delivery, urban professionals

**Market Share:** 8-10% in operational cities

**Meatvo Differentiation:**
- ⚡ 30-minute delivery vs. 24-hour
- 💰 15-20% cheaper pricing
- 🎯 Lower MOV (₹300)
- 🚀 Impulse purchase enabled

---

#### Competitor 2: FreshToHome

**Overview:**
- Founded: 2015
- Funding: $121M (Series C)
- Presence: 50+ cities
- Customers: 1.5M+

**Strengths:**
- ✅ Direct farm sourcing (B2B relationships)
- ✅ No middleman (price advantage)
- ✅ Wide geographic presence
- ✅ Chemical-free claim (no antibiotics)
- ✅ Subscription model

**Weaknesses:**
- ❌ 2-hour delivery window (not hyperlocal)
- ❌ Limited meat variety (150 SKUs)
- ❌ Quality inconsistency (user reviews)
- ❌ Poor app UX (3.8-star rating)
- ❌ Customer service issues (slow response)

**Positioning:** Chemical-free, farm-to-fork, price-conscious

**Market Share:** 5-7% in operational cities

**Meatvo Differentiation:**
- ⚡ 30-minute vs. 2-hour delivery
- 🎨 Superior app UX (4.5+ target rating)
- 🛡️ Quality consistency (FSSAI-certified dark stores)
- 💬 24/7 customer support (in-app chat)

---

#### Competitor 3: Zappfresh

**Overview:**
- Founded: 2015
- Funding: $14M (Series B)
- Presence: Delhi-NCR, Mumbai
- Customers: 500K+

**Strengths:**
- ✅ Affordable pricing (competitive with local markets)
- ✅ North India focus (mutton, chicken)
- ✅ COD available (cash-preferred customers)
- ✅ Marinated products (ready-to-cook)

**Weaknesses:**
- ❌ Limited presence (only 2 cities)
- ❌ Next-day delivery (no instant gratification)
- ❌ Basic app UX (outdated design)
- ❌ No real-time tracking
- ❌ Limited customer support

**Positioning:** Affordable, next-day delivery, North India

**Market Share:** 3-5% in Delhi-NCR

**Meatvo Differentiation:**
- ⚡ 30-minute vs. next-day delivery
- 🌍 Pan-India expansion (not region-specific)
- 🎨 Modern app UX (Gen Z appeal)
- 📍 Real-time tracking (order transparency)

---

### 6.2 Indirect Competitors

#### Competitor 4: Zepto / Blinkit / Swiggy Instamart

**Overview:**
- Quick commerce players with meat category
- 10-30 minute delivery
- Wide product range (groceries + meat)

**Strengths:**
- ✅ Hyperlocal (10-30 min delivery)
- ✅ High brand trust (Swiggy, Zepto)
- ✅ Large customer base (10M+ users)
- ✅ Cross-category shopping (convenience)

**Weaknesses:**
- ❌ Limited meat selection (30-50 SKUs, pre-packaged)
- ❌ No meat expertise (generalist approach)
- ❌ Quality concerns (shelf-life optimization)
- ❌ No cold chain specialization
- ❌ No traceability (unknown sourcing)

**Positioning:** Hyperlocal, instant gratification, groceries-first

**Market Share:** 5-8% of meat purchases (incidental, not primary)

**Meatvo Differentiation:**
- 🥩 Meat-first approach (100+ SKUs)
- 🧊 Specialized cold chain (0-4°C maintained)
- 🏷️ QR code traceability (farm source)
- 👨‍🍳 Meat expertise (cuts, recipes, cooking tips)

---

#### Competitor 5: Traditional Butchers

**Overview:**
- 80% market share (unorganized sector)
- Neighborhood butchers, wet markets

**Strengths:**
- ✅ Immediate availability (walk-in purchase)
- ✅ Lowest pricing (no middleman)
- ✅ Personal relationships (decades-long trust)
- ✅ Custom cuts (on-demand)

**Weaknesses:**
- ❌ Hygiene concerns (open-air cutting, no cold chain)
- ❌ No traceability (unknown sourcing)
- ❌ Limited hours (closed by 7 PM)
- ❌ Inconvenient (physical travel required)
- ❌ No payment transparency (haggling required)

**Positioning:** Traditional, lowest price, personal relationships

**Market Share:** 80% (declining, especially among young urban)

**Meatvo Differentiation:**
- 🏠 Home delivery (no travel required)
- 🧼 Hygiene certified (FSSAI, cold chain)
- 🏷️ Transparent pricing (no haggling)
- 📱 Digital convenience (app-based ordering)
- ⏰ 24/7 availability (no closing time)

---

### 6.3 Competitive Matrix

| Feature | Meatvo | Licious | FreshToHome | Zepto/Blinkit | Traditional Butchers |
|---------|--------|---------|-------------|---------------|---------------------|
| **Delivery Speed** | 30 min | 24 hours | 2 hours | 10-30 min | Immediate (walk-in) |
| **Product Range** | 100+ SKUs | 300+ SKUs | 150 SKUs | 30-50 SKUs | 50+ SKUs |
| **Pricing** | Mid (₹280/kg chicken) | High (₹350/kg) | Mid (₹270/kg) | High (₹320/kg) | Low (₹250/kg) |
| **Quality** | High (FSSAI) | Very High | Medium | Medium | Variable |
| **Traceability** | Yes (QR code) | Yes | Yes | No | No |
| **Cold Chain** | Specialized | Specialized | Specialized | Basic | None |
| **Payment Options** | COD + Online | Online only | COD + Online | Online only | Cash only |
| **App UX** | Modern (4.5+ target) | Good (4.2) | Basic (3.8) | Excellent (4.5+) | N/A |
| **Customer Support** | 24/7 chat | 9 AM-9 PM | Limited | 24/7 | In-person only |
| **Subscription** | Yes (₹299/month) | Yes (daily) | Yes (weekly) | No | No |
| **Geographic Presence** | 1 city (expanding) | 15 cities | 50+ cities | 15+ cities | Everywhere |

**Competitive Positioning:**

```
                    High Price
                        │
          Licious       │
            ●           │
                        │
                        │        Meatvo ★
                        │          ●
    Slow ───────────────┼───────────────────── Fast
    Delivery            │                    Delivery
                        │
                        │  FreshToHome
                        │      ●
          Traditional   │              Zepto
          Butchers      │                ●
              ●         │
                        │
                    Low Price
```

**Key Takeaway:** Meatvo occupies the **"Fast + Affordable + Quality"** quadrant — a white space in the market.

---

## 7. User Roles

### 7.1 Customer (Primary User)

**Role Definition:**  
End-user who browses products, places orders, makes payments, and tracks deliveries.

**Key Capabilities:**
- Authentication (OTP-based phone login)
- Profile management (name, email, addresses)
- Product discovery (browse catalog, search, filter)
- Cart management (add, update, remove items)
- Checkout (address, delivery slot, payment)
- Order tracking (real-time GPS, status updates)
- Order history (reorder, rate, review)
- Support (in-app chat, call customer care)

**Permissions:**
- View own profile, orders, addresses
- Place orders (up to ₹20,000 per order for new users)
- Cancel orders (before "PICKED_UP" status)
- Rate & review orders (after delivery)

**Success Metrics:**
- Time to first order: <5 minutes (onboarding to checkout)
- Order frequency: 2+ orders per month
- Retention rate: 60% (3-month)
- NPS: 75+

---

### 7.2 Rider (Delivery Partner)

**Role Definition:**  
Delivery executive who picks up orders from dark stores and delivers to customers.

**Key Capabilities:**
- Authentication (phone OTP login)
- Order management (view assigned orders, accept/reject)
- Navigation (Google Maps integration, route optimization)
- Location tracking (real-time GPS updates every 10 seconds)
- Status updates (picked up, out for delivery, delivered)
- Payment collection (COD orders, scan QR codes)
- Earnings tracking (daily, weekly, monthly)

**Permissions:**
- View assigned orders only (not all orders)
- Update order status (only assigned orders)
- Collect COD payments
- Contact customer (in-app call, privacy-protected)

**Success Metrics:**
- Orders per day: 20-25
- On-time delivery: >92%
- Customer rating: 4.5+
- Utilization rate: >75%
- Monthly churn: <10%

---

### 7.3 Admin (Operations Team)

**Role Definition:**  
Internal team managing products, orders, inventory, riders, and analytics.

**Roles:**
1. **Super Admin:** Full access (system config, user management)
2. **Operations Manager:** Order management, rider assignment
3. **Inventory Manager:** Product CRUD, stock management
4. **Customer Support:** Order issues, refunds, customer queries
5. **Analyst:** View-only analytics, reports

**Key Capabilities:**
- Dashboard (real-time metrics: orders, revenue, active users)
- Product management (create, update, delete products/categories)
- Order management (view all orders, assign riders, update status)
- Inventory management (stock levels, low stock alerts)
- User management (customers, riders, admins)
- Rider management (onboarding, performance tracking, payouts)
- Analytics (sales reports, customer insights, rider performance)
- Promotions (banners, coupons, discounts)
- Settings (delivery slots, service areas, pricing rules)

**Permissions:**
- View all data (customers, orders, riders)
- Modify products, inventory, pricing
- Assign/reassign riders to orders
- Issue refunds, cancel orders
- Generate reports (sales, inventory, performance)

**Success Metrics:**
- Order processing time: <30 seconds
- Rider assignment time: <2 minutes
- Support response time: <5 minutes
- Inventory accuracy: >98%

---

### 7.4 Role-Based Access Control (RBAC)

**Permission Matrix:**

| Feature | Customer | Rider | Support | Operations | Inventory | Super Admin |
|---------|----------|-------|---------|------------|-----------|-------------|
| **Browse Products** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Place Order** | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **View Own Orders** | ✅ | ✅ (assigned) | ✅ (support cases) | ✅ (all) | ❌ | ✅ |
| **Update Order Status** | ❌ | ✅ (assigned) | ❌ | ✅ | ❌ | ✅ |
| **Assign Riders** | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ |
| **Manage Products** | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| **Manage Inventory** | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| **Issue Refunds** | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ |
| **View Analytics** | ❌ | ✅ (own earnings) | ❌ | ✅ | ✅ | ✅ |
| **Manage Users** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 8. Customer Journey

### 8.1 Customer Journey Map

#### Journey 1: First-Time User (Onboarding → First Order)

**Stage 1: Awareness**
- **Touchpoint:** Google Search, Instagram ad, word-of-mouth
- **Action:** Sees Meatvo ad ("Fresh Chicken delivered in 30 minutes")
- **Emotion:** 😐 Curious but skeptical ("Another meat app?")
- **Pain Point:** Tired of slow delivery from Licious

**Stage 2: Consideration**
- **Touchpoint:** App Store listing, reviews (4.5+ stars)
- **Action:** Downloads app, views product catalog without signing up
- **Emotion:** 🤔 Impressed by pricing ("20% cheaper than Licious")
- **Pain Point:** Hesitant to share phone number (privacy concerns)

**Stage 3: Acquisition**
- **Touchpoint:** Guest checkout prompt → OTP login
- **Action:** Enters phone number, receives OTP, verifies
- **Emotion:** 😊 Smooth onboarding ("That was easy!")
- **Pain Point:** None (OTP arrives within 5 seconds)

**Stage 4: Activation**
- **Touchpoint:** Location permission, address setup
- **Action:** Allows location access, adds delivery address
- **Emotion:** 🙂 Confident ("They're asking for permission, not forcing")
- **Pain Point:** Manual address entry (mitigated by GPS autofill)

**Stage 5: First Order**
- **Touchpoint:** Product catalog → cart → checkout
- **Action:** Browses "Chicken" category, adds "Boneless Breast 500g", selects delivery slot (8-9 PM), chooses COD
- **Emotion:** 😀 Excited ("Let's see if 30-minute delivery is real")
- **Pain Point:** Small doubt about quality ("Will it be as fresh as claimed?")

**Stage 6: Delivery**
- **Touchpoint:** Real-time tracking, rider location on map
- **Action:** Watches rider approach on map, receives SMS ("Rider 5 min away")
- **Emotion:** 😊 Impressed ("Wow, actual real-time tracking!")
- **Pain Point:** None (rider arrives in 28 minutes)

**Stage 7: Post-Purchase**
- **Touchpoint:** Product quality inspection, cooking
- **Action:** Checks packaging (vacuum-sealed, temp tag shows 2°C), cooks chicken
- **Emotion:** 😍 Delighted ("This is fresher than my local butcher!")
- **Pain Point:** None (exceeded expectations)

**Stage 8: Retention**
- **Touchpoint:** In-app rating prompt, push notification (next day)
- **Action:** Rates 5 stars, receives push ("Order again, get ₹50 off")
- **Emotion:** 🥰 Loyal ("I'm switching from Licious")
- **Pain Point:** None (hooked)

---

#### Journey 2: Repeat User (Browse → Reorder)

**Stage 1: Trigger**
- **Context:** Tuesday evening, 8 PM, just reached home from work
- **Thought:** "Need chicken for dinner, but too tired to cook elaborate meal"
- **Action:** Opens Meatvo app

**Stage 2: Browse**
- **Action:** Sees "Reorder" button on home screen (shows "Boneless Breast 500g" from last order)
- **Emotion:** 😊 Convenient ("They remember my preference!")
- **Action:** Clicks "Reorder", cart pre-filled

**Stage 3: Checkout**
- **Action:** Reviews cart (₹280), default address pre-selected, chooses delivery slot (8:30-9:00 PM), pays with UPI
- **Emotion:** 🚀 Fast ("Checkout in 30 seconds!")
- **Action:** Confirms order

**Stage 4: Delivery**
- **Action:** Continues working, receives push notification ("Order delivered!")
- **Emotion:** 🎉 Satisfied ("Didn't even have to track, just arrived")
- **Time:** 27 minutes from order to delivery

**Stage 5: Post-Purchase**
- **Action:** No rating prompt (already rated last order)
- **Emotion:** 🙂 Routine ("Meatvo is now my default for meat")

---

#### Journey 3: Power User (Subscription)

**Stage 1: Frequent Orders**
- **Context:** Ordering 3-4x per week for 2 months
- **Observation:** Spending ₹50-60 on delivery fees per month

**Stage 2: Subscription Discovery**
- **Touchpoint:** In-app banner ("Save ₹300/month with Meatvo Prime — ₹299/month")
- **Calculation:** Current delivery fees ₹200/month → Prime saves ₹100/month + 10% discount on orders
- **Action:** Clicks banner, views Prime benefits

**Stage 3: Subscription Purchase**
- **Touchpoint:** Prime checkout page
- **Benefits Highlighted:**
  - Free delivery on all orders
  - 10% discount on all products
  - Priority customer support
  - Early access to new products
- **Action:** Subscribes (₹299/month, auto-renew)
- **Emotion:** 🤑 Smart ("This pays for itself in 3 orders")

**Stage 4: Subscription Usage**
- **Behavior Change:** Orders 5-6x per month (increased frequency, no delivery fee friction)
- **AOV Increase:** ₹650 → ₹850 (adds more items, 10% discount makes it affordable)
- **Emotion:** 😎 VIP ("I'm a Meatvo loyalist now")

---

### 8.2 Rider Journey

**Stage 1: Onboarding**
- **Touchpoint:** Rider recruitment ad → offline interview → app download
- **Action:** Downloads Meatvo Rider app, completes profile (Aadhaar, license, bank account)
- **Emotion:** 😊 Hopeful ("Better earnings than Swiggy")
- **Training:** 2-hour session (app usage, cold chain handling, customer etiquette)

**Stage 2: First Day**
- **Action:** Logs into app, receives first order assignment
- **Emotion:** 😬 Nervous ("Hope I don't mess up")
- **Support:** Call with operations team (walkthrough)

**Stage 3: Regular Workday**
- **Action:** Completes 20-25 deliveries/day, earns ₹1,200-1,500
- **Emotion:** 🙂 Satisfied ("Earning more than Zomato, less traffic stress")
- **Pain Point:** Peak hour congestion (7-9 PM)

**Stage 4: Performance Tracking**
- **Touchpoint:** Weekly earnings report, customer ratings
- **Action:** Views stats (4.7-star rating, 94% on-time delivery)
- **Emotion:** 😊 Proud ("I'm a top performer")
- **Incentive:** Bonus ₹500 for maintaining 4.5+ rating

---

### 8.3 Admin Journey

**Stage 1: Morning Dashboard Review**
- **Action:** Logs into admin panel, views dashboard (orders today, revenue, active riders)
- **Insight:** 12 pending orders, 8 riders active, ₹25K revenue so far
- **Action:** Assigns pending orders to nearest riders

**Stage 2: Inventory Management**
- **Alert:** Low stock alert (Chicken Breast <10 units)
- **Action:** Creates purchase order for supplier, updates stock levels
- **Emotion:** ✅ Organized ("Inventory under control")

**Stage 3: Customer Support**
- **Incident:** Customer complains about late delivery (45 minutes)
- **Action:** Checks rider GPS logs (traffic jam on route), calls customer, offers ₹100 discount
- **Emotion:** 😓 Stressful (but resolved)
- **Follow-Up:** Logs incident, shares feedback with rider

**Stage 4: Analytics Review**
- **Touchpoint:** Weekly business review meeting
- **Action:** Generates reports (order trends, top products, rider performance)
- **Insight:** Chicken breast sales up 30% (promotion successful)
- **Decision:** Increase stock levels, extend promotion

---

## 9. Functional Requirements

### 9.1 Customer App (Flutter - iOS/Android)

#### 9.1.1 Authentication & Profile

**FR-1.1:** Phone Number Authentication (OTP)
- User enters phone number (+91 format)
- System sends 6-digit OTP via SMS (MSG91)
- User enters OTP, system verifies (5-minute expiry, 3 attempts max)
- On success, generate JWT tokens (access + refresh)
- Store tokens securely (flutter_secure_storage)

**FR-1.2:** Profile Management
- User can view/edit profile (name, email, profile picture)
- Upload profile picture (max 5MB, jpg/png/webp)
- System stores image in Cloudflare R2, returns CDN URL
- User can view order history, saved addresses

**FR-1.3:** Session Management
- Access token expires in 15 minutes
- Refresh token expires in 30 days
- Auto-refresh token on expiry (silent, no user action)
- Logout invalidates both tokens

---

#### 9.1.2 Product Discovery

**FR-2.1:** Product Catalog
- Display products in grid/list view (default: grid)
- Show product image, name, price, unit, discount badge
- Filter by category (Chicken, Mutton, Fish, Eggs, Groceries)
- Sort by: Price (low-to-high), Popularity, New Arrivals
- Pagination (20 products per page, infinite scroll)

**FR-2.2:** Product Search
- Search bar with auto-suggestions (top 5 matches)
- Full-text search on product name, description, tags
- Search results page with filters (category, price range)
- Recent searches (last 5 searches, local storage)

**FR-2.3:** Product Detail Page
- Display full product info (name, images carousel, price, MRP, discount %, unit, description)
- Nutritional information (calories, protein, fat, carbs per 100g)
- QR code traceability (farm source, processing date, expiry)
- Add to cart button (quantity selector: 1-10)
- Related products carousel (4-6 items)

**FR-2.4:** Category Browsing
- Display category tree (parent → child categories)
- Category images, product counts
- Filter products by subcategory
- Example: Chicken → Fresh Cuts → Breast, Thighs, Wings

---

#### 9.1.3 Cart & Checkout

**FR-3.1:** Cart Management
- Add products to cart (quantity 1-10 per product)
- Update quantity (increment/decrement buttons)
- Remove product from cart (swipe-to-delete)
- Cart persistence (synced to Redis, survives app close)
- Cart summary (subtotal, item count, estimated delivery fee)

**FR-3.2:** Checkout Flow
- Select delivery address (from saved addresses or add new)
- Choose delivery slot (Morning 8-12, Afternoon 12-4, Evening 4-8)
- Apply coupon code (optional, validates on backend)
- Select payment method (COD or Online: UPI/Card/Wallet)
- Review order summary (subtotal, delivery fee, discount, tax, total)
- Place order button (creates order, redirects to payment if online)

**FR-3.3:** Address Management
- View saved addresses (list view)
- Add new address (manual entry or GPS autofill)
- Edit address (update fields)
- Delete address (soft delete)
- Set default address (radio button)
- Address validation (pincode serviceability check)

**FR-3.4:** Payment Integration (Razorpay)
- Online payment: Redirect to Razorpay checkout
- Payment options: UPI, Cards, Net Banking, Wallets
- Payment verification (signature validation on backend)
- COD: No payment gateway, marked as "PENDING" payment status
- Retry payment (if failed)

---

#### 9.1.4 Order Tracking

**FR-4.1:** Order Confirmation
- Display order confirmation screen (order number, ETA, delivery address)
- Send push notification ("Order confirmed, preparing your items")
- Send SMS with order details

**FR-4.2:** Real-Time Tracking
- Display order status (Confirmed → Preparing → Ready → Picked Up → Out for Delivery → Delivered)
- Show rider location on map (Google Maps, updates every 10 seconds)
- Display rider info (name, phone, rating)
- ETA countdown (dynamic, based on rider distance)
- Status update notifications (push + in-app)

**FR-4.3:** Order History
- List past orders (sorted by date, descending)
- Show order summary (order number, date, total, status)
- Filter by status (Delivered, Cancelled)
- Reorder button (adds same items to cart)
- View order details (items, address, payment)

**FR-4.4:** Order Cancellation
- Cancel order button (visible until "PICKED_UP" status)
- Cancellation reason selection (Changed mind, Wrong address, etc.)
- Refund initiation (if online payment, auto-refund in 3-5 days)
- Cancellation confirmation notification

---

#### 9.1.5 Support & Engagement

**FR-5.1:** Customer Support
- In-app chat (24/7 support, typing indicator, read receipts)
- Call customer care (click-to-call, privacy-protected number)
- FAQs section (collapsible accordion)
- Report issue (dropdown: wrong item, quality issue, late delivery)

**FR-5.2:** Ratings & Reviews
- Rate order after delivery (1-5 stars)
- Rate rider separately (1-5 stars)
- Write review (optional text feedback, max 500 chars)
- View product reviews (read-only, from other customers)

**FR-5.3:** Notifications
- Push notifications (order updates, promotions, reminders)
- In-app notifications (bell icon, unread badge count)
- Notification settings (toggle on/off for categories)
- Deep linking (tap notification → open relevant screen)

**FR-5.4:** Promotions & Offers
- Banner carousel on home screen (3-5 rotating banners)
- Coupon code list (view available coupons, copy code)
- Referral program (share referral code, earn credits)
- Meatvo Prime subscription (free delivery, 10% discount)

---

### 9.2 Rider App (Flutter - iOS/Android)

#### 9.2.1 Authentication & Profile

**FR-6.1:** Rider Login
- Phone OTP authentication (same as customer app)
- Role validation (only users with role "RIDER" can access)
- Profile setup (name, photo, vehicle details, license)

**FR-6.2:** Rider Profile
- View earnings (daily, weekly, monthly)
- View ratings (average rating, recent feedback)
- View delivery stats (total deliveries, on-time %, cancellations)
- Edit profile (update phone, vehicle details)

---

#### 9.2.2 Order Management

**FR-7.1:** Order Assignment
- Receive push notification ("New order assigned")
- View order details (order number, customer name, address, items, payment method)
- Accept/Reject order (30-second timer, auto-reject if no response)
- View pickup location (dark store address, navigation button)

**FR-7.2:** Order Pickup
- Navigate to dark store (Google Maps integration)
- Mark "Picked Up" (updates order status, notifies customer)
- View items list (verify order contents with store staff)

**FR-7.3:** Order Delivery
- Navigate to customer address (Google Maps, optimized route)
- Real-time location sharing (GPS updates every 10 seconds via WebSocket)
- Call customer (click-to-call, privacy-protected)
- Mark "Out for Delivery" (auto-triggered when leaving dark store vicinity)
- Mark "Delivered" (requires photo proof for high-value orders >₹2000)
- Collect COD payment (if applicable, enter amount collected)

**FR-7.4:** Order Issues
- Report issue (customer not reachable, wrong address, refused order)
- Escalate to support (in-app chat with operations team)
- Return to store (if customer unavailable after 2 attempts)

---

#### 9.2.3 Earnings & Performance

**FR-8.1:** Earnings Dashboard
- View daily earnings (breakdown: base fee, distance bonus, tips, incentives)
- View weekly summary (total earnings, completed deliveries)
- View payout history (bank transfers, dates, amounts)
- Download earnings report (PDF)

**FR-8.2:** Performance Tracking
- View ratings (customer feedback, last 30 days)
- View on-time delivery % (target: >92%)
- View acceptance rate (target: >80%)
- Incentive eligibility (e.g., bonus for 4.5+ rating, 20+ orders/day)

---

### 9.3 Admin Web Dashboard (React/Next.js)

#### 9.3.1 Dashboard & Analytics

**FR-9.1:** Overview Dashboard
- Display KPI cards (orders today, revenue today, active riders, active customers)
- Display charts (orders over time, revenue trend, top products)
- Display real-time metrics (pending orders, riders online)
- Display alerts (low stock, delayed orders, rider issues)

**FR-9.2:** Analytics & Reports
- Sales report (daily, weekly, monthly, custom date range)
- Customer insights (new vs. returning, cohort analysis, churn rate)
- Product performance (best-sellers, slow-movers, inventory turnover)
- Rider performance (on-time %, ratings, earnings)
- Download reports (CSV, PDF)

---

#### 9.3.2 Product Management

**FR-10.1:** Product CRUD
- View products (table view, search, filter by category)
- Create product (form: name, description, category, price, MRP, unit, images, tags)
- Edit product (update any field)
- Delete product (soft delete, hidden from customer app)
- Bulk upload (CSV import for 100+ products)

**FR-10.2:** Category Management
- View categories (hierarchical tree view)
- Create category (name, slug, parent category, image, display order)
- Edit category (update fields)
- Delete category (only if no products associated)

**FR-10.3:** Inventory Management
- View stock levels (table view, low stock alerts)
- Update stock (manual entry or bulk CSV upload)
- Set low stock thresholds (alert when <10 units)
- View stock movement (in/out, date, reason)

---

#### 9.3.3 Order Management

**FR-11.1:** Order Dashboard
- View all orders (table view, search by order number/customer name)
- Filter by status (Pending, Confirmed, Out for Delivery, etc.)
- Sort by date, total amount
- Export orders (CSV)

**FR-11.2:** Order Details
- View order details (customer, address, items, payment, rider, status logs)
- Update order status (dropdown: Confirmed → Preparing → Ready)
- Assign rider (dropdown: select from available riders, sorted by proximity)
- Cancel order (reason required, refund initiated)
- Issue refund (full/partial)

**FR-11.3:** Order Assignment
- Auto-assign rider (algorithm: nearest rider with <5 active orders)
- Manual assign (admin selects rider)
- Reassign rider (if original rider unavailable)
- Batch assignment (assign multiple orders to same rider for route optimization)

---

#### 9.3.4 User Management

**FR-12.1:** Customer Management
- View customers (table view, search by name/phone/email)
- View customer details (profile, order history, total spend, LTV)
- Block/unblock customer (prevent fraud)
- Send notification (push or SMS)

**FR-12.2:** Rider Management
- View riders (table view, search by name/phone)
- View rider details (profile, earnings, performance, ratings)
- Onboard new rider (form: name, phone, license, vehicle, bank account)
- Deactivate rider (if performance below threshold)
- Assign incentives (bonus for top performers)

**FR-12.3:** Admin User Management
- View admins (table view, filter by role)
- Create admin (form: name, email, role, permissions)
- Edit admin (update role, permissions)
- Delete admin (soft delete)
- Roles: Super Admin, Operations Manager, Inventory Manager, Support, Analyst

---

#### 9.3.5 Promotions & Marketing

**FR-13.1:** Banner Management
- View banners (table view, active/inactive)
- Create banner (image upload, title, subtitle, link type: product/category/URL)
- Edit banner (update fields, display order)
- Schedule banner (start/end date)
- Delete banner

**FR-13.2:** Coupon Management
- View coupons (table view, active/inactive)
- Create coupon (code, discount type: % or fixed, value, min order, max discount, usage limit)
- Edit coupon (update fields)
- Deactivate coupon (prevent further use)
- View coupon usage (how many times used, by whom)

**FR-13.3:** Referral Program
- Configure referral rewards (referrer credit, referee credit)
- View referral stats (total referrals, conversion rate)
- View leaderboard (top referrers)

---

#### 9.3.6 Settings & Configuration

**FR-14.1:** Delivery Slots
- View delivery slots (table view)
- Create slot (label, start time, end time, capacity)
- Edit slot (update fields)
- Deactivate slot (temporarily disable)

**FR-14.2:** Service Area Management
- Define service areas (pincode list or polygon on map)
- Set delivery fees (per area, dynamic pricing rules)
- Set minimum order value (per area)
- Check serviceability (enter pincode, view if serviceable)

**FR-14.3:** System Settings
- Configure payment gateways (Razorpay keys)
- Configure SMS gateway (MSG91 keys)
- Configure Firebase FCM (push notifications)
- Configure Cloudflare R2 (storage)
- Configure Google Maps API (location services)

---

## 10. Non-Functional Requirements

### 10.1 Performance

**NFR-1:** API Response Time
- **Requirement:** P95 response time <200ms for all REST endpoints
- **Measurement:** Prometheus metrics, Grafana dashboards
- **Acceptance Criteria:** 95% of API requests complete within 200ms

**NFR-2:** App Launch Time
- **Requirement:** Cold start <3 seconds, warm start <1 second
- **Measurement:** Firebase Performance Monitoring
- **Acceptance Criteria:** 90% of app launches meet target

**NFR-3:** Real-Time Tracking Latency
- **Requirement:** Rider location updates visible to customer within 2 seconds
- **Measurement:** WebSocket ping/pong latency monitoring
- **Acceptance Criteria:** 95% of location updates delivered within 2s

**NFR-4:** Database Query Performance
- **Requirement:** P95 query time <50ms
- **Measurement:** PostgreSQL slow query logs, pg_stat_statements
- **Acceptance Criteria:** No queries >500ms (optimize immediately if detected)

**NFR-5:** Image Load Time
- **Requirement:** Product images load <1 second on 4G connection
- **Measurement:** CDN analytics (Cloudflare)
- **Acceptance Criteria:** 90% of images cached at edge, served <1s

---

### 10.2 Scalability

**NFR-6:** Concurrent Users
- **Requirement:** Support 10,000 concurrent users (Phase 1), scale to 100,000 (Phase 3)
- **Architecture:** Stateless application servers, horizontal scaling (Docker containers)
- **Acceptance Criteria:** Load testing (k6) validates 10K users with <200ms latency

**NFR-7:** Order Processing Capacity
- **Requirement:** Process 5,000 orders/hour (Phase 1), scale to 50,000 (Phase 3)
- **Architecture:** Asynchronous job processing (Bull Queue), database read replicas
- **Acceptance Criteria:** Stress test validates capacity with 0% order failures

**NFR-8:** Database Scalability
- **Requirement:** Support 10M+ orders in database (Year 3)
- **Architecture:** Table partitioning (monthly), read replicas, sharding (geographic)
- **Acceptance Criteria:** Query performance maintained (<50ms) at scale

**NFR-9:** Storage Scalability
- **Requirement:** Store 1M+ product images (100GB+)
- **Architecture:** Cloudflare R2 (S3-compatible, unlimited scalability)
- **Acceptance Criteria:** Image upload/retrieval works at any scale

---

### 10.3 Reliability & Availability

**NFR-10:** System Uptime
- **Requirement:** 99.9% uptime SLA (max 43 minutes downtime per month)
- **Architecture:** Load balancing, health checks, auto-restart (Docker), database backups
- **Acceptance Criteria:** Uptime monitoring (Grafana) shows 99.9%+ over 30-day rolling window

**NFR-11:** Database Backup & Recovery
- **Requirement:** RTO (Recovery Time Objective) <2 hours, RPO (Recovery Point Objective) <1 hour
- **Architecture:** Daily full backups, 6-hour incremental backups to Cloudflare R2
- **Acceptance Criteria:** Quarterly disaster recovery drill succeeds within RTO/RPO

**NFR-12:** Error Rate
- **Requirement:** API error rate <0.1% (1 error per 1000 requests)
- **Monitoring:** Prometheus alerting (>5% error rate triggers PagerDuty)
- **Acceptance Criteria:** 30-day error rate <0.1%

**NFR-13:** Payment Success Rate
- **Requirement:** >97% payment success rate (Razorpay + backend)
- **Monitoring:** Payment gateway logs, retry mechanism for failures
- **Acceptance Criteria:** Weekly payment success rate >97%

---

### 10.4 Security

**NFR-14:** Authentication Security
- **Requirement:** JWT tokens with 15-minute expiry (access), 30-day expiry (refresh)
- **Implementation:** HS256 algorithm, 256-bit secrets, token rotation on refresh
- **Acceptance Criteria:** Penetration testing validates no authentication bypass

**NFR-15:** Data Encryption
- **Requirement:** AES-256 encryption at rest (database), TLS 1.3 in transit (API)
- **Implementation:** PostgreSQL pgcrypto, Let's Encrypt SSL certificates
- **Acceptance Criteria:** SSL Labs rating A+ (target)

**NFR-16:** Payment Security
- **Requirement:** PCI-DSS compliant (via Razorpay), no card data stored on Meatvo servers
- **Implementation:** Razorpay tokenization, webhook signature validation
- **Acceptance Criteria:** Annual PCI-DSS compliance audit passes

**NFR-17:** API Rate Limiting
- **Requirement:** 100 requests/minute per user, 3 OTP requests/hour per phone
- **Implementation:** Redis-backed rate limiting (Nginx + application layer)
- **Acceptance Criteria:** Rate limit enforcement tested, 429 errors returned correctly

**NFR-18:** Data Privacy
- **Requirement:** GDPR-ready (data export, deletion), DPDP Act compliance
- **Implementation:** User data export API, anonymization on deletion
- **Acceptance Criteria:** Legal review validates compliance

---

### 10.5 Usability

**NFR-19:** App Accessibility
- **Requirement:** WCAG 2.1 AA compliance (color contrast, font sizes, screen reader support)
- **Implementation:** Semantic HTML, ARIA labels, sufficient contrast ratios
- **Acceptance Criteria:** Accessibility audit passes

**NFR-20:** Onboarding Time
- **Requirement:** User completes first order within 5 minutes of app download
- **Measurement:** Analytics funnel (download → signup → first order)
- **Acceptance Criteria:** 70% of users complete first order within 5 minutes

**NFR-21:** Error Messaging
- **Requirement:** User-friendly error messages (no technical jargon)
- **Implementation:** Standardized error response format, helpful messages
- **Acceptance Criteria:** User testing validates clarity

**NFR-22:** Multilingual Support (Roadmap Phase 2)
- **Requirement:** Support Hindi, Tamil, Telugu, Marathi (top 5 languages by user base)
- **Implementation:** i18n library (Flutter), translation keys
- **Acceptance Criteria:** 100% of UI strings translated

---

### 10.6 Maintainability

**NFR-23:** Code Quality
- **Requirement:** Test coverage >80% (unit + integration tests)
- **Implementation:** Jest (backend), Flutter test framework
- **Acceptance Criteria:** CI/CD blocks deployment if coverage <80%

**NFR-24:** API Documentation
- **Requirement:** Swagger/OpenAPI documentation for all REST endpoints
- **Implementation:** NestJS Swagger decorators, auto-generated docs
- **Acceptance Criteria:** Documentation 100% up-to-date with API

**NFR-25:** Monitoring & Observability
- **Requirement:** Centralized logging, distributed tracing, alerting
- **Implementation:** Winston logs, Prometheus metrics, Grafana dashboards
- **Acceptance Criteria:** MTTD (Mean Time to Detect) <5 minutes, MTTR (Mean Time to Resolve) <1 hour

**NFR-26:** Deployment Frequency
- **Requirement:** Deploy to production daily (CI/CD automation)
- **Implementation:** GitHub Actions (test → build → deploy), rollback capability
- **Acceptance Criteria:** 90% of deployments succeed without rollback

---

### 10.7 Compatibility

**NFR-27:** Mobile OS Support
- **Requirement:** iOS 13+, Android 8.0+ (covers 95%+ of users)
- **Implementation:** Flutter compatibility matrix
- **Acceptance Criteria:** App runs on target OS versions without crashes

**NFR-28:** Browser Support (Admin Dashboard)
- **Requirement:** Chrome 90+, Firefox 88+, Safari 14+, Edge 90+
- **Implementation:** React compatibility, polyfills
- **Acceptance Criteria:** Dashboard functional on all target browsers

**NFR-29:** Screen Size Support
- **Requirement:** Mobile (320px-428px width), tablet (768px-1024px), desktop (1280px+)
- **Implementation:** Responsive design (Flutter adaptive widgets)
- **Acceptance Criteria:** UI renders correctly on all target screen sizes

---

## 11. Success Metrics

### 11.1 Customer Acquisition Metrics

**Metric 1: User Sign-Ups**
- **Definition:** Number of users who complete phone OTP verification
- **Target:** 10,000 users (Month 6), 100,000 users (Month 18)
- **Measurement:** Analytics dashboard (daily, weekly, monthly sign-ups)

**Metric 2: Activation Rate**
- **Definition:** % of sign-ups who complete first order within 7 days
- **Target:** 40% (Month 6), 50% (Month 18)
- **Formula:** (Users with 1+ order / Total sign-ups) x 100
- **Measurement:** Cohort analysis (weekly cohorts)

**Metric 3: Customer Acquisition Cost (CAC)**
- **Definition:** Total marketing spend / New customers acquired
- **Target:** ₹180 (Month 6), ₹150 (Month 18)
- **Formula:** (Marketing spend + sales spend) / New customers
- **Measurement:** Monthly financial report

---

### 11.2 Engagement Metrics

**Metric 4: Daily Active Users (DAU)**
- **Definition:** Number of unique users who open app per day
- **Target:** 1,000 DAU (Month 6), 15,000 DAU (Month 18)
- **Measurement:** Firebase Analytics, daily tracking

**Metric 5: Monthly Active Users (MAU)**
- **Definition:** Number of unique users who open app per month
- **Target:** 10,000 MAU (Month 6), 100,000 MAU (Month 18)
- **Measurement:** Firebase Analytics, monthly tracking

**Metric 6: Order Frequency**
- **Definition:** Average orders per active user per month
- **Target:** 2 orders/month (Month 6), 3 orders/month (Month 18)
- **Formula:** Total orders / MAU
- **Measurement:** SQL query on orders table

---

### 11.3 Retention Metrics

**Metric 7: Repeat Purchase Rate**
- **Definition:** % of customers who make 2+ orders
- **Target:** 30% (Month 3), 50% (Month 12), 60% (Month 24)
- **Formula:** (Customers with 2+ orders / Total customers) x 100
- **Measurement:** Cohort analysis (30-day, 90-day cohorts)

**Metric 8: Customer Retention Rate**
- **Definition:** % of customers who order again within 30 days
- **Target:** 40% (Month 6), 60% (Month 18)
- **Formula:** (Customers who ordered in Month N / Customers who ordered in Month N-1) x 100
- **Measurement:** Monthly cohort retention matrix

**Metric 9: Churn Rate**
- **Definition:** % of customers who don't order for 90+ days
- **Target:** <30% (Month 12)
- **Formula:** (Inactive customers / Total customers) x 100
- **Measurement:** Quarterly analysis

---

### 11.4 Revenue Metrics

**Metric 10: Gross Merchandise Value (GMV)**
- **Definition:** Total value of orders placed (before discounts, delivery fees)
- **Target:** ₹15 Cr (Year 1), ₹60 Cr (Year 2), ₹180 Cr (Year 3)
- **Measurement:** Sum of order subtotals

**Metric 11: Average Order Value (AOV)**
- **Definition:** Average cart value per order
- **Target:** ₹850 (Month 6), ₹900 (Month 18)
- **Formula:** Total GMV / Number of orders
- **Measurement:** Monthly average

**Metric 12: Revenue (Net)**
- **Definition:** GMV + Delivery fees + Subscription fees - Discounts
- **Target:** ₹4.5 Cr (Year 1), ₹19.2 Cr (Year 2), ₹59.4 Cr (Year 3)
- **Measurement:** Financial reporting (monthly P&L)

**Metric 13: Customer Lifetime Value (LTV)**
- **Definition:** Total revenue generated by a customer over their lifetime
- **Target:** ₹4,200 (6 months, 12 orders @ ₹350 AOV)
- **Formula:** AOV x Order frequency x Customer lifetime (months)
- **Measurement:** Cohort-based LTV analysis

---

### 11.5 Operational Metrics

**Metric 14: On-Time Delivery Rate**
- **Definition:** % of orders delivered within promised 30-minute window
- **Target:** 85% (Month 3), 90% (Month 6), 92% (Month 12)
- **Formula:** (Orders delivered on time / Total orders) x 100
- **Measurement:** Order status logs (created_at vs. delivered_at)

**Metric 15: Order Cancellation Rate**
- **Definition:** % of orders cancelled (by customer or system)
- **Target:** <5% (Month 6)
- **Formula:** (Cancelled orders / Total orders) x 100
- **Measurement:** Daily tracking, root cause analysis

**Metric 16:** Product Return/Quality Complaint Rate
- **Definition:** % of orders with quality complaints
- **Target:** <2% (Month 6)
- **Formula:** (Orders with complaints / Total orders) x 100
- **Measurement:** Customer support tickets tagged "quality issue"

**Metric 17: Rider Utilization Rate**
- **Definition:** % of rider work hours actively delivering orders
- **Target:** 75% (Month 6), 85% (Month 18)
- **Formula:** (Active delivery time / Total logged-in time) x 100
- **Measurement:** Rider GPS logs, order status timestamps

---

### 11.6 Customer Satisfaction Metrics

**Metric 18: Net Promoter Score (NPS)**
- **Definition:** Customer willingness to recommend Meatvo (0-10 scale)
- **Target:** 60 (Month 3), 70 (Month 12), 75 (Month 24)
- **Formula:** % Promoters (9-10) - % Detractors (0-6)
- **Measurement:** In-app survey (post-delivery), monthly NPS calculation

**Metric 19: App Rating**
- **Definition:** Average rating on App Store/Google Play
- **Target:** 4.3 (Month 3), 4.5+ (Month 12)
- **Measurement:** App Store Connect, Google Play Console (weekly tracking)

**Metric 20: Customer Support Response Time**
- **Definition:** Average time to first response (in-app chat)
- **Target:** <5 minutes (Month 6)
- **Measurement:** Chat system logs (message timestamp analysis)

**Metric 21: Customer Support Resolution Rate**
- **Definition:** % of support tickets resolved on first contact
- **Target:** 80% (Month 6)
- **Formula:** (Tickets resolved without escalation / Total tickets) x 100
- **Measurement:** Support ticketing system (Zendesk/Intercom)

---

## 12. Key Performance Indicators (KPIs)

### 12.1 North Star Metric

**Orders Per Week**
- **Definition:** Total orders placed per week (all customers)
- **Why North Star:** Directly correlates with revenue, customer satisfaction, and operational efficiency
- **Current:** 0 (pre-launch)
- **Target Month 6:** 1,250 orders/week (5,000/month)
- **Target Month 18:** 12,500 orders/week (50,000/month)
- **Target Month 36:** 125,000 orders/week (500,000/month)

---

### 12.2 Product KPIs

#### Growth KPIs

| KPI | Current | Month 6 Target | Month 18 Target | Month 36 Target |
|-----|---------|----------------|-----------------|-----------------|
| **Monthly Active Users (MAU)** | 0 | 10,000 | 100,000 | 1,000,000 |
| **New Sign-Ups/Month** | 0 | 2,000 | 15,000 | 100,000 |
| **Orders/Month** | 0 | 5,000 | 50,000 | 500,000 |
| **GMV/Month** | ₹0 | ₹42.5L | ₹5 Cr | ₹50 Cr |

#### Engagement KPIs

| KPI | Current | Month 6 Target | Month 18 Target | Month 36 Target |
|-----|---------|----------------|-----------------|-----------------|
| **Order Frequency** | 0 | 2 orders/user/month | 3 orders/user/month | 4 orders/user/month |
| **Repeat Purchase Rate** | 0% | 30% | 50% | 60% |
| **App Open Rate** | 0% | 40% (DAU/MAU) | 50% | 60% |
| **Cart Abandonment Rate** | - | 30% | 25% | 20% |

#### Retention KPIs

| KPI | Current | Month 6 Target | Month 18 Target | Month 36 Target |
|-----|---------|----------------|-----------------|-----------------|
| **30-Day Retention** | 0% | 40% | 60% | 70% |
| **90-Day Retention** | 0% | 25% | 40% | 50% |
| **Churn Rate** | 0% | 35% | 25% | 20% |

#### Monetization KPIs

| KPI | Current | Month 6 Target | Month 18 Target | Month 36 Target |
|-----|---------|----------------|-----------------|-----------------|
| **Average Order Value (AOV)** | ₹0 | ₹850 | ₹900 | ₹950 |
| **Customer Lifetime Value (LTV)** | ₹0 | ₹3,400 (4 months) | ₹4,200 (6 months) | ₹5,400 (9 months) |
| **CAC:LTV Ratio** | - | 1:18.9 | 1:28 | 1:27 |
| **Subscription Adoption** | 0% | 5% | 15% | 25% |

---

### 12.3 Operational KPIs

#### Delivery Performance

| KPI | Current | Month 6 Target | Month 18 Target | Month 36 Target |
|-----|---------|----------------|-----------------|-----------------|
| **On-Time Delivery Rate** | - | 85% | 92% | 95% |
| **Average Delivery Time** | - | 32 minutes | 28 minutes | 25 minutes |
| **Order Accuracy** | - | 96% | 98% | 99% |
| **Order Cancellation Rate** | - | 7% | 5% | 3% |

#### Rider Performance

| KPI | Current | Month 6 Target | Month 18 Target | Month 36 Target |
|-----|---------|----------------|-----------------|-----------------|
| **Rider Utilization Rate** | - | 70% | 75% | 85% |
| **Orders/Rider/Day** | - | 18 | 22 | 25 |
| **Rider Retention (Monthly)** | - | 85% | 90% | 92% |
| **Average Rider Rating** | - | 4.3 | 4.5 | 4.7 |

#### Quality & Support

| KPI | Current | Month 6 Target | Month 18 Target | Month 36 Target |
|-----|---------|----------------|-----------------|-----------------|
| **Product Quality Complaint Rate** | - | 3% | 2% | 1% |
| **Customer Support Response Time** | - | 8 minutes | 5 minutes | 3 minutes |
| **First Contact Resolution** | - | 75% | 80% | 85% |
| **NPS** | - | 60 | 70 | 75 |

---

### 12.4 Financial KPIs

| KPI | Month 6 Target | Month 18 Target | Month 36 Target |
|-----|----------------|-----------------|-----------------|
| **Monthly Revenue** | ₹37.5L | ₹1.6 Cr | ₹4.95 Cr |
| **Gross Margin** | 33% | 35% | 37% |
| **Contribution Margin** | 28% | 32% | 35% |
| **EBITDA Margin** | -40% | -5% | +5% |
| **Monthly Burn Rate** | $125K | $80K | $0 (break-even) |
| **Cash Runway** | 18 months | 24 months | Profitable |

---

### 12.5 Technical KPIs

| KPI | Target | Measurement |
|-----|--------|-------------|
| **API Response Time (P95)** | <200ms | Prometheus + Grafana |
| **System Uptime** | 99.9% | Uptime monitoring |
| **App Crash Rate** | <0.1% | Firebase Crashlytics |
| **Payment Success Rate** | >97% | Razorpay logs |
| **Database Query Time (P95)** | <50ms | pg_stat_statements |
| **Real-Time Tracking Latency** | <2s | WebSocket ping/pong |

---

### 12.6 KPI Tracking & Reporting

**Daily Tracking:**
- Orders placed, GMV, AOV
- New sign-ups, DAU
- On-time delivery rate, cancellation rate
- System uptime, API response time

**Weekly Tracking:**
- MAU, order frequency
- Repeat purchase rate, cart abandonment
- Rider utilization, orders per rider
- Customer support metrics (response time, resolution rate)

**Monthly Tracking:**
- Revenue, gross margin, contribution margin, EBITDA
- CAC, LTV, CAC:LTV ratio
- 30-day retention, churn rate
- NPS, app rating

**Quarterly Tracking:**
- 90-day retention
- Competitive benchmarking (market share, pricing)
- Investor reporting (fundraising readiness)

**Dashboard Tools:**
- **Grafana:** Real-time operational metrics (orders, delivery, system health)
- **Metabase/Looker:** Business intelligence (revenue, cohorts, funnels)
- **Firebase Analytics:** App engagement (DAU, MAU, screen views)
- **Google Sheets/Excel:** Financial modeling (P&L, projections)

---

## 13. Revenue Model

### 13.1 Revenue Streams

#### Stream 1: Product Sales (95% of Revenue)

**Model:** Direct sale of products (chicken, mutton, fish, eggs, groceries)

**Pricing Strategy:**
- **Value Tier:** Competitive with traditional butchers (GP: 25%)
  - Example: Chicken breast ₹280/kg (vs. ₹250 local butcher, ₹350 Licious)
- **Premium Tier:** Specialty cuts, organic, marinated (GP: 40%)
  - Example: Organic chicken ₹450/kg (vs. ₹550 Licious)
- **Bundle Offers:** Family packs, weekly baskets (GP: 30%)
  - Example: Family chicken pack (1kg breast + 500g curry cut) ₹550 (10% discount)

**Unit Economics (Example: Chicken Breast 500g @ ₹140):**
```
Selling Price:           ₹140
COGS (Procurement):      ₹85  (60%)
Gross Profit:            ₹55  (40% GP)
Variable Costs:
  - Packaging:           ₹5
  - Cold Chain:          ₹3
  - Payment Gateway:     ₹4   (2% + ₹3)
Contribution Margin:     ₹43  (31% CM)
```

**Revenue Projections (Bokaro Steel City):**

| Year | Orders/Month | AOV | Monthly Product Revenue | Annual Product Revenue |
|------|--------------|-----|-------------------------|------------------------|
| Y1   | 2,000-2,500 (avg) | ₹650 | ₹13-16L | ₹1.5-1.9 Cr |
| Y2   | 6,000-8,000 (avg) | ₹700 | ₹42-56L | ₹5-6.7 Cr |
| Y3   | 15,000-18,000 (avg) | ₹750 | ₹1.1-1.35 Cr | ₹13.5-16 Cr |

**Note:** Revenue = GMV (assumes GMV ≈ product sales for simplicity)

---

#### Stream 2: Delivery Fees (3% of Revenue)

**Model:** Per-order delivery charge based on distance and slot

**Pricing:**
- **Standard Delivery (0-3 km):** ₹30
- **Extended Delivery (3-5 km):** ₹50
- **Prime Members:** Free delivery (all orders)
- **Surge Pricing:** +₹20 during peak hours (7-9 PM) or bad weather

**Unit Economics (Example: 3km delivery @ ₹30):**
```
Delivery Fee:            ₹30
Rider Payout:            ₹20  (₹15 base + ₹5 distance)
Net Delivery Margin:     ₹10  (33% margin)
```

**Strategy:**
- Delivery fees offset rider costs, but not full profit center (encourage orders, not revenue maximization)
- Free delivery for orders >₹500 (promote higher AOV)
- Prime subscription (₹299/month) offers free delivery (customer acquisition)

**Revenue Projections (Delivery Fees - Bokaro):**

| Year | Orders/Month | Avg Delivery Fee | Monthly Delivery Revenue | Annual Delivery Revenue |
|------|--------------|------------------|--------------------------|------------------------|
| Y1   | 2,000-2,500 | ₹25 | ₹5-6.25L | ₹6-7.5L |
| Y2   | 6,000-8,000 | ₹30 | ₹18-24L | ₹21.6-28.8L |
| Y3   | 15,000-18,000 | ₹30 | ₹45-54L | ₹54-64.8L |

---

#### Stream 3: Subscription (Meatvo Prime) (2% of Revenue)

**Model:** Monthly subscription (₹299/month) offering:
- Free delivery on all orders
- 10% discount on all products
- Priority customer support
- Early access to new products

**Unit Economics:**
```
Subscription Fee:        ₹299/month
Cost to Serve:
  - Delivery subsidy:    ₹100 (4 orders x ₹25 avg fee)
  - Discount subsidy:    ₹120 (4 orders x ₹850 AOV x 3.5% effective discount)
  - Support cost:        ₹10
Net Subscription Margin: ₹69  (23% margin)
```

**Adoption Strategy:**
- Target: 5% adoption (Month 6) → 15% (Month 18) → 25% (Month 36)
- Payback: 3 orders per month (subscription pays for itself in delivery fees saved)
- LTV Boost: Prime members order 2x more frequently (from 2 to 4 orders/month)

**Revenue Projections (Subscription):**

| Year | MAU | Prime Adoption | Prime Members | Monthly Subscription Revenue | Annual Subscription Revenue |
|------|-----|----------------|---------------|------------------------------|----------------------------|
| Y1 (Month 6) | 10,000 | 5% | 500 | ₹1.5L | ₹18L (prorated) |
| Y2 | 100,000 | 15% | 15,000 | ₹44.85L | ₹5.38 Cr |
| Y3 | 800,000 | 25% | 200,000 | ₹598L | ₹71.76 Cr |

---

### 13.2 Revenue Breakdown

**Year 1 (Month 12):**
```
Product Sales:       ₹5.1 Cr   (94%)
Delivery Fees:       ₹15L       (3%)
Subscription:        ₹18L       (3%)
────────────────────────────────────
Total Revenue:       ₹5.43 Cr
```

**Year 3 (Month 36):**
```
Product Sales:       ₹2,850 Cr  (97%)
Delivery Fees:       ₹9 Cr      (0.3%)
Subscription:        ₹71.76 Cr  (2.7%)
────────────────────────────────────
Total Revenue:       ₹2,930.76 Cr
```

**Note:** Delivery fees decline as % of revenue (more Prime subscribers get free delivery)

---

### 13.3 Pricing Strategy

#### Competitive Positioning

| Product | Local Butcher | Meatvo | Licious | FreshToHome |
|---------|---------------|--------|---------|-------------|
| Chicken Breast (500g) | ₹125 | ₹140 | ₹175 | ₹150 |
| Mutton Curry Cut (500g) | ₹350 | ₹380 | ₹450 | ₹400 |
| Fish (Pomfret, 500g) | ₹300 | ₹320 | ₹380 | ₹340 |
| Eggs (12 pack) | ₹60 | ₹72 | ₹90 | ₹75 |

**Meatvo Premium vs. Local Butcher:** 10-15% higher (justifiable with hygiene, traceability, convenience)  
**Meatvo vs. Licious:** 15-20% cheaper (key differentiator)  
**Meatvo vs. FreshToHome:** On-par pricing (compete on speed, UX)

#### Dynamic Pricing (Roadmap Phase 2)

**Factors:**
- **Demand:** Surge pricing during peak hours (+10-15%)
- **Supply:** Discount slow-moving inventory (-20%)
- **Competition:** Price matching if competitor undercuts by >10%
- **Loyalty:** Personalized discounts for churning customers

---

### 13.4 Unit Economics Summary

**Per Order Economics (Mature State, Month 18):**
```
Average Order Value (AOV):       ₹850
───────────────────────────────────────
Revenue:
  Product Sale:                  ₹850
  Delivery Fee:                  ₹30
  Total Revenue:                 ₹880
───────────────────────────────────────
Costs:
  COGS (60%):                    ₹510
  Delivery (Rider):              ₹25
  Packaging:                     ₹15
  Payment Gateway (2%+₹3):       ₹20
  Cold Chain:                    ₹10
  Marketing (CAC amortized):     ₹15  (₹180 CAC / 12 orders)
  Fixed Costs (tech, ops):       ₹35
  Total Costs:                   ₹630
───────────────────────────────────────
Gross Profit:                    ₹340  (40% GP)
Contribution Margin:             ₹250  (29% CM)
EBITDA:                          ₹220  (25% EBITDA margin)
```

**Profitability Milestones:**
- **Contribution Margin Positive:** Month 3 (CM >0%)
- **EBITDA Positive (Launch City):** Month 18
- **EBITDA Positive (Overall):** Month 24

---

### 13.5 Monetization Optimization

**Strategies to Improve Unit Economics:**

1. **Increase AOV:**
   - Bundles (family packs, weekly baskets)
   - Cross-sell (marinades, cooking oil with meat)
   - Free delivery above ₹500 (incentivizes larger carts)
   - **Target:** ₹850 → ₹950 (12% increase)

2. **Reduce COGS:**
   - Direct farm partnerships (eliminate middleman)
   - Bulk procurement discounts
   - Private label products (marinades, ready-to-cook)
   - **Target:** 60% → 58% (2% COGS reduction)

3. **Increase Order Frequency:**
   - Subscription (Meatvo Prime) → 2x order frequency
   - Push notifications (recipe recommendations, weekly reminders)
   - Loyalty program (10th order free)
   - **Target:** 2 orders/month → 4 orders/month

4. **Reduce CAC:**
   - Referral program (₹100 credit for referrer + referee)
   - Organic growth (word-of-mouth, high NPS)
   - Content marketing (SEO, recipe blogs, Instagram)
   - **Target:** ₹180 → ₹150 (17% reduction)

---

## 14. Risk Analysis

### 14.1 Market Risks

#### Risk 1: Intense Competition

**Description:** Licious, FreshToHome, and quick commerce players (Zepto, Blinkit) aggressively defend market share.

**Impact:** High  
**Probability:** High

**Mitigation:**
1. **Differentiation:** 30-minute delivery (vs. 24-hour Licious, 2-hour FreshToHome)
2. **Pricing:** 15-20% cheaper than Licious (attract price-sensitive customers)
3. **Quality:** FSSAI-certified, QR code traceability (build trust)
4. **Customer Experience:** Superior app UX, real-time tracking, 24/7 support
5. **Rapid Expansion:** Capture market share in 3 cities before competitors react (first-mover advantage in hyperlocal meat)

**Contingency:**
- Raise Series A earlier (Month 9 vs. Month 12) to outspend competitors
- Launch aggressive referral program (₹200 credit vs. ₹100)
- Price match if competitors undercut by >10%

---

#### Risk 2: Market Size Overestimation

**Description:** Online meat market grows slower than projected (15% penetration vs. 25% expected).

**Impact:** High  
**Probability:** Medium

**Mitigation:**
1. **Pilot Validation:** Prove demand in 1 city before expanding (Month 1-6)
2. **Conservative Projections:** Base Series A ask on 50% of projected demand
3. **Pivot Readiness:** If meat demand low, expand to adjacent categories (groceries, dairy, ready-to-cook)
4. **Customer Education:** Marketing campaigns highlighting hygiene, convenience (address trust barriers)

**Contingency:**
- Expand product range (groceries, dairy) to increase TAM
- Reduce burn rate (delay expansion to Month 9 vs. Month 7)
- Focus on Prime subscriptions (lock-in customers, recurring revenue)

---

### 14.2 Operational Risks

#### Risk 3: Cold Chain Failure

**Description:** Temperature control breach (refrigeration failure, rider mishandling) leads to spoiled meat, food poisoning.

**Impact:** Critical (brand damage, legal liability)  
**Probability:** Low

**Mitigation:**
1. **IoT Monitoring:** Temperature sensors in dark stores, rider bags (real-time alerts if >4°C)
2. **Redundancy:** Backup refrigeration in dark stores (generator + UPS)
3. **Rider Training:** Mandatory cold chain handling training, audits every 2 weeks
4. **Insurance:** Product liability insurance (₹1 Cr coverage)
5. **Quality Checks:** Multi-stage inspection (farm → processing → store → delivery)

**Contingency:**
- Immediate product recall if temperature breach detected
- Replacement order + ₹500 credit for affected customers
- Public apology + transparency report (restore trust)
- Legal team on retainer for liability cases

---

#### Risk 4: Rider Shortage

**Description:** Insufficient riders during peak hours (7-9 PM, weekends) leads to delayed deliveries, customer dissatisfaction.

**Impact:** High  
**Probability:** Medium

**Mitigation:**
1. **Rider Pool:** Maintain 20% buffer capacity (hire 120 riders if 100 needed)
2. **Surge Incentives:** +₹50 bonus per order during peak hours (attract gig riders)
3. **Partnerships:** Partner with Dunzo, Shadowfax for overflow orders
4. **Scheduling:** Encourage off-peak orders (₹20 discount for 3-5 PM slots)
5. **Retention:** Competitive pay (₹1,500/day), health insurance, training

**Contingency:**
- Extend delivery windows during peak demand (30 min → 45 min, inform customer upfront)
- Outsource to third-party logistics (Dunzo API integration)
- Offer credits for late deliveries (auto-credit ₹50 if >40 min)

---

### 14.3 Financial Risks

#### Risk 5: Cash Runway Depletion

**Description:** Burn rate exceeds projections, Series A fundraise delayed, company runs out of cash.

**Impact:** Critical (shutdown risk)  
**Probability:** Medium

**Mitigation:**
1. **Lean Operations:** Bootstrap MVP with $500K Seed, avoid unnecessary hires
2. **Milestone-Based Fundraising:** Raise Series A at Month 9 (when traction proven, not Month 18)
3. **Revenue Focus:** Push Prime subscriptions (recurring revenue, cash flow positive)
4. **Cost Control:** Negotiate supplier credit terms (30-day payment, vs. upfront)
5. **Bridge Financing:** Convertible notes from existing investors (if Series A delayed)

**Contingency:**
- Delay expansion (focus on profitability in 1 city vs. expanding to 3)
- Reduce marketing spend (pause paid ads, rely on organic growth)
- Layoffs (last resort, reduce team by 20%)

---

#### Risk 6: Unit Economics Don't Improve

**Description:** Contribution margin remains negative (e.g., -10%) despite scale, business unprofitable.

**Impact:** Critical (investor exit, shutdown)  
**Probability:** Low

**Mitigation:**
1. **Regular Audits:** Monthly unit economics review (flag issues early)
2. **Pricing Adjustments:** Increase prices by 5-10% if margins compressed
3. **Cost Reduction:** Renegotiate supplier contracts (10% COGS reduction at scale)
4. **AOV Increase:** Bundles, cross-sell, minimum order value (₹300 → ₹500)
5. **Subscription Push:** Prime members generate 2x revenue (focus on adoption)

**Contingency:**
- Pivot to higher-margin products (marinated, ready-to-cook, private label)
- Introduce premium tier (organic, grass-fed) with 50% GP
- Exit unprofitable cities (focus on profitable ones)

---

### 14.4 Technology Risks

#### Risk 7: System Downtime

**Description:** Backend crash, database corruption, or DDoS attack leads to prolonged outage (>1 hour).

**Impact:** High (revenue loss, customer churn)  
**Probability:** Low

**Mitigation:**
1. **High Availability:** 99.9% uptime SLA, load balancing, auto-restart (Docker)
2. **Monitoring:** Real-time alerts (PagerDuty, Grafana), 24/7 on-call engineer
3. **Backup:** Daily database backups (RTO: 2 hours, RPO: 1 hour)
4. **DDoS Protection:** Cloudflare (absorbs 99% of attacks)
5. **Disaster Recovery:** Runbooks for incident response, quarterly DR drills

**Contingency:**
- Display maintenance message to customers (transparency)
- Offer ₹100 credit for orders placed during outage
- Expedite recovery (call all engineering team, full-hands-on-deck)

---

#### Risk 8: Data Breach

**Description:** Hacker gains access to customer data (phone, address, order history).

**Impact:** Critical (legal liability, brand damage, fines)  
**Probability:** Low

**Mitigation:**
1. **Encryption:** AES-256 at rest, TLS 1.3 in transit (no plaintext storage)
2. **Authentication:** JWT tokens, OTP-based login (no password vulnerabilities)
3. **Access Control:** RBAC, least privilege (only admins access sensitive data)
4. **Auditing:** Log all data access (detect anomalies)
5. **Penetration Testing:** Quarterly external security audits

**Contingency:**
- Immediate password reset (if compromised)
- Public disclosure within 72 hours (GDPR, DPDP Act requirement)
- Credit monitoring service for affected customers (₹500/year)
- Legal counsel for compliance (fines, lawsuits)

---

### 14.5 Regulatory Risks

#### Risk 9: FSSAI Non-Compliance

**Description:** Dark store fails FSSAI audit (hygiene violation, expired products), license revoked.

**Impact:** Critical (shutdown of store, reputation damage)  
**Probability:** Low

**Mitigation:**
1. **Compliance Officer:** Hire FSSAI expert (consultant or full-time)
2. **Regular Audits:** Monthly internal audits, quarterly external audits
3. **Training:** All staff trained on FSSAI regulations (documented)
4. **Documentation:** Maintain all records (sourcing, temp logs, expiry dates)
5. **Pre-Launch Audit:** Third-party audit before store opening (catch issues early)

**Contingency:**
- Immediate remediation (fix violations within 7 days)
- Temporary closure (if necessary, redirect orders to other stores)
- Public statement (transparency, corrective action plan)

---

#### Risk 10: Local Municipal Restrictions

**Description:** Local government restricts home deliveries (zoning laws, lockdown) or bans meat sales (religious festivals).

**Impact:** High (revenue loss, operational disruption)  
**Probability:** Low

**Mitigation:**
1. **Legal Research:** Understand local laws before launching in new city
2. **Licenses:** Obtain all required licenses (trade license, health permit)
3. **Relationships:** Build relationships with local authorities (proactive communication)
4. **Advance Notice:** Monitor government announcements (prepare for festivals, lockdowns)

**Contingency:**
- Diversify cities (if 1 city restricted, others still operational)
- Pivot to adjacent products (eggs, groceries) if meat banned temporarily
- Offer pickup option (customers collect from dark store, no delivery)

---

### 14.6 Risk Summary Matrix

| Risk | Impact | Probability | Severity | Priority | Mitigation Cost |
|------|--------|-------------|----------|----------|-----------------|
| Intense Competition | High | High | Critical | 1 | High (marketing spend) |
| Cash Runway Depletion | Critical | Medium | Critical | 2 | Medium (lean ops) |
| Unit Economics Don't Improve | Critical | Low | Critical | 3 | Medium (pricing, cost reduction) |
| Cold Chain Failure | Critical | Low | Critical | 4 | High (IoT, insurance) |
| Data Breach | Critical | Low | Critical | 5 | Medium (security audits) |
| Market Size Overestimation | High | Medium | High | 6 | Low (pilot validation) |
| Rider Shortage | High | Medium | High | 7 | Medium (rider pool, incentives) |
| System Downtime | High | Low | High | 8 | Medium (monitoring, backups) |
| FSSAI Non-Compliance | Critical | Low | High | 9 | Medium (audits, training) |
| Local Municipal Restrictions | High | Low | Medium | 10 | Low (legal research) |

---

## 15. MVP Scope

### 15.1 MVP Definition

**Minimum Viable Product (MVP):** The smallest feature set required to launch in **Bokaro Steel City (5-10km radius)**, acquire 3,000-5,000 users, and validate product-market fit within 6 months.

**Launch Timeline:** Q3 2026 (Bokaro Steel City, Jharkhand)

**Service Area:**
- **Primary:** Sector 1-12, City Centre, Chas
- **Radius:** 5-10 km from dark store (Sector 4 location)
- **Dark Store:** 1 store initially (300-400 sq ft rental space)

**MVP Goals:**
1. Prove 30-45 minute delivery in Bokaro is operationally viable
2. Validate willingness to pay (₹650 AOV, 35% repeat rate)
3. Achieve unit economics viability (contribution margin >0%)
4. Scale to 2,000-3,000 orders/month
5. Bootstrap or raise ₹25-50 Lakh angel funding (local investors/SAIL network)

---

### 15.2 MVP Features (In Scope)

#### Customer App (Essential)

✅ **Authentication:**
- Phone OTP login
- Profile setup (name, email)
- Session persistence

✅ **Product Discovery:**
- Browse product catalog (grid view)
- Category filtering (Chicken, Mutton, Fish, Eggs)
- Product search (text search)
- Product detail page (images, price, description, nutrition)

✅ **Cart & Checkout:**
- Add to cart, update quantity, remove
- Cart summary (subtotal, delivery fee, total)
- Address management (add, edit, delete, select)
- Delivery slot selection (Morning, Afternoon, Evening)
- Payment (COD + Razorpay online)

✅ **Order Tracking:**
- Order confirmation screen
- Order status updates (Confirmed → Delivered)
- Real-time rider location (Google Maps)
- Order history (list view, reorder button)
- Order cancellation (before pickup)

✅ **Support:**
- In-app chat (24/7 support)
- Call customer care (click-to-call)
- FAQs section

✅ **Notifications:**
- Push notifications (order updates)
- SMS notifications (order confirmation, OTP)

---

#### Rider App (Essential)

✅ **Authentication:**
- Phone OTP login
- Role validation (RIDER only)

✅ **Order Management:**
- View assigned orders
- Accept/reject order
- Navigate to pickup (Google Maps)
- Mark picked up, out for delivery, delivered
- Collect COD payment

✅ **Location Tracking:**
- Real-time GPS updates (every 10 seconds)
- Auto-location sharing during delivery

✅ **Earnings:**
- View daily earnings
- View weekly summary

---

#### Admin Dashboard (Essential)

✅ **Dashboard:**
- KPI cards (orders today, revenue, active riders)
- Order list (filter by status, search)

✅ **Product Management:**
- View products (table view)
- Create, edit, delete products
- Update stock levels

✅ **Order Management:**
- View order details
- Assign rider (manual or auto)
- Update order status
- Cancel order, issue refund

✅ **User Management:**
- View customers (basic info, order history)
- View riders (basic info, performance)

---

### 15.3 MVP Features (Out of Scope — Future Phases)

❌ **Phase 2 (Post-MVP):**
- Product ratings & reviews (customer)
- Wishlist
- Recipe recommendations
- Voice search
- Dark mode
- Vernacular languages (Hindi, Kannada)
- Rider earnings analytics (detailed charts)
- Admin analytics dashboard (Grafana charts)
- Coupon management (admin)
- Banner management (admin)

❌ **Phase 3 (Scale):**
- Meatvo Prime subscription
- Referral program
- Loyalty points
- In-app wallet
- Scheduled orders (pre-order for tomorrow)
- Bulk orders (catering, parties)
- Video recipes
- AR product visualization
- Alexa/Google Assistant integration

---

### 15.4 MVP Technical Specifications

#### Frontend (Flutter)

**Platforms:** iOS 13+, Android 8.0+  
**State Management:** Riverpod  
**HTTP Client:** Dio  
**Real-Time:** Socket.io client  
**Local Storage:** Hive (cart, session)  
**Secure Storage:** flutter_secure_storage (tokens)  
**Maps:** Google Maps Flutter  
**Notifications:** Firebase FCM

**Screens (Customer App):** 25 screens
- Auth: 4 (splash, phone input, OTP, profile setup)
- Home: 5 (home, category list, product list, product detail, search)
- Cart: 3 (cart, checkout, payment)
- Orders: 4 (order confirmation, tracking, history, detail)
- Profile: 4 (profile, addresses, settings, support)
- Misc: 5 (onboarding, location permission, FAQs, chat, notifications)

**Screens (Rider App):** 8 screens
- Auth: 2 (login, profile)
- Orders: 4 (order list, order detail, navigation, delivery proof)
- Earnings: 2 (earnings dashboard, history)

---

#### Backend (NestJS)

**Runtime:** Node.js 20 LTS  
**Framework:** NestJS 10.x  
**Language:** TypeScript 5.x  
**Database:** PostgreSQL 15.x  
**Cache:** Redis 7.x  
**ORM:** TypeORM 0.3.x  
**Authentication:** JWT (access + refresh tokens)  
**Payment:** Razorpay integration  
**Real-Time:** Socket.io 4.x  
**Storage:** Cloudflare R2 (S3-compatible)  
**SMS:** MSG91 (OTP)  
**Maps:** Google Maps API (geocoding)

**Modules:** 15 modules
- Auth, Users, Addresses, Products, Categories, Cart, Orders, Payments, Delivery, Admin, Notifications, Uploads, Settings, Health, Metrics

**API Endpoints:** 50+ REST endpoints  
**WebSocket Events:** 10+ events (order status, rider location)

---

#### Infrastructure

**Hosting:** Ubuntu VPS (DigitalOcean/AWS EC2)  
**Containerization:** Docker + Docker Compose  
**Reverse Proxy:** Nginx (load balancing, SSL)  
**CDN:** Cloudflare (static assets, DDoS protection)  
**SSL:** Let's Encrypt (auto-renewal)  
**CI/CD:** GitHub Actions (test → build → deploy)  
**Monitoring:** Prometheus + Grafana  
**Backup:** Daily database backups to Cloudflare R2

---

### 15.5 MVP Launch Plan

#### Pre-Launch (Months 1-3)

**Month 1:**
- Finalize MVP scope (this PRD)
- Design UI/UX (Figma mockups - simple, local-friendly)
- Set up development environment (repos, basic CI/CD)
- **Team:** 1 full-stack dev, 1 operations person (can be founder)

**Month 2:**
- Build backend API (authentication, products, orders)
- Build Android app (primary - 90% of Bokaro users on Android)
- Set up infrastructure (shared VPS, ₹2-3K/month)
- Integrate payment gateway (Razorpay for online, COD primary)

**Month 3:**
- Build rider app (simple version with Google Maps navigation)
- Build admin web panel (basic product/order management)
- QA testing (manual testing with 10-15 beta users)
- **Set up dark store:**
  - Location: Sector 4 (central location, good connectivity)
  - Size: 300-400 sq ft rental (₹8-12K/month)
  - Equipment: 2 deep freezers, 1 refrigerator (₹80K one-time)
  - Stock: 30-40 SKUs (chicken, mutton, fish, eggs)
- Onboard 3-4 riders (part-time initially, ₹400-500/day)
- Local licenses: FSSAI registration, trade license

#### Launch (Month 4)

**Soft Launch (Week 1-2):**
- Beta launch in 2-3 SAIL colonies/sectors (invite-only, 50-100 users)
- **Marketing:** 
  - WhatsApp groups (SAIL colony groups, apartment groups)
  - Word-of-mouth (friends, family, colleagues)
  - Printed flyers in Sector 4, City Centre
- Gather feedback (phone calls, WhatsApp feedback)
- Fix critical bugs, optimize delivery routes
- Target: 50 users, 30-40 orders in first 2 weeks

**Public Launch (Week 3-4):**
- Google Play launch (Android only, Bokaro geo-targeted)
- **Marketing campaigns:**
  - Facebook/Instagram ads (Bokaro-targeted, ₹500-1000/day)
  - Local newspaper ad (Dainik Jagran, Prabhat Khabar)
  - Pamphlet distribution at City Centre, Sector 4 market
  - WhatsApp status, groups sharing
  - First order discount: ₹100 off (limited to 200 users)
- Target: 300-500 users, 150-200 orders in Month 4

#### Post-Launch (Months 5-6)

**Growth & Optimization:**
- Scale to 1,500-2,000 users (Month 5), 3,000-5,000 users (Month 6)
- Achieve 2,000-3,000 orders/month
- **Growth tactics:**
  - Referral program: ₹50 credit for referrer + referee
  - Colony-wise targeting (SAIL Sector 1-12, one by one)
  - Partner with local clubs (SAIL Club, Lions Club)
  - Weekend sampling at City Centre
- Iterate on feedback (improve app, reduce delivery time to 30-35 min)
- Optimize unit economics (negotiate with suppliers, reduce wastage)
- **Funding decision:**
  - If profitable: Bootstrap, expand organically
  - If need capital: Raise ₹25-50 Lakh from local angels/SAIL network

---

### 15.6 MVP Success Criteria

**Launch Success (Month 4):**
- ✅ App live on Google Play (Android)
- ✅ 300-500 users acquired in Bokaro
- ✅ 150-200 orders placed
- ✅ 85% of orders delivered within 40 minutes (5-10km radius)
- ✅ 0 critical bugs (app crashes, payment failures)
- ✅ NPS >55 (good start for local market)

**Traction Success (Month 6):**
- ✅ 3,000-5,000 MAU (strong local presence)
- ✅ 2,000-3,000 orders/month
- ✅ 35-40% repeat purchase rate (strong word-of-mouth)
- ✅ ₹650-700 AOV
- ✅ Contribution margin >0% (unit economics viable in local market)
- ✅ NPS >65
- ✅ App rating 4.2+ stars (Google Play)
- ✅ Known brand in 5-6 SAIL sectors

**Expansion Readiness (Month 6):**
- ✅ Proven product-market fit in Bokaro (35%+ repeat rate)
- ✅ Operational viability (85%+ orders on time)
- ✅ Financial viability (CM >0%, path to break-even clear)
- ✅ Strong local reputation (testimonials from SAIL families, colony groups)
- ✅ Clear expansion plan (2nd store in Gomia/Chas, or replicate in Dhanbad)

---

## 16. Future Roadmap

### 16.1 Phase 2: Bokaro Expansion (Months 7-18)

**Geographic Expansion (Within Bokaro):**
- Open 2nd store in Gomia/Chandrapura (Month 9-10)
- Expand service radius to 15-20 km total
- Cover adjacent areas: Jaridih, Phusro, Tenughat
- Target: 12,000-15,000 MAU in expanded Bokaro area

**Product Features:**
- Referral program (Month 8) - critical for local growth
- Product ratings & reviews (Month 10)
- Hindi language support (Month 11) - 70% of users prefer Hindi
- Recipe recommendations (Month 13) - local cuisine focus
- Basic loyalty (Month 15) - 10th order free

**Operational Enhancements:**
- Better inventory management (reduce wastage to <5%, Month 8)
- Supplier partnerships (direct from chicken farms, Month 9)
- Better delivery routing (optimize for Bokaro roads, Month 10)
- Basic analytics dashboard (track daily metrics, Month 11)

**Business Milestones:**
- 8,000-10,000 orders/month (Month 12)
- Break-even in Bokaro operations (Month 15-18)
- Profitable enough to self-fund Dhanbad launch (Month 18)

---

### 16.2 Phase 3: Regional Expansion (Months 19-36)

**Geographic Expansion (If Bokaro Profitable):**
- Launch in Dhanbad (Month 20-22) - 85 km from Bokaro, similar demographics
- Launch in Ranchi (Month 28-30) - capital city, larger market
- Optionally: Jamshedpur (Month 34-36)
- Target: 3 cities in Jharkhand, 30,000-40,000 MAU total

**Product Features:**
- Loyalty program (points, rewards, Month 20)
- Scheduled orders (weekly recurring, Month 22)
- Bulk orders (parties, functions, Month 24)
- WhatsApp ordering (Month 26) - convenience for older users
- Bengali language support (Month 28) - for Jharkhand market

**Technology Enhancements:**
- Better server (if needed, Month 20)
- Mobile app optimization (reduce size, faster load, Month 22)
- Inventory forecasting (reduce wastage with basic ML, Month 24)
- Multi-store management system (Month 26)

**Business Milestones:**
- 20,000-25,000 orders/month across 3 cities (Month 30)
- 10-15% EBITDA margin (Month 30)
- Self-sustaining, profitable business
- GMV: ₹15-20 Cr/year (Month 36)
- Potential to raise growth capital (₹2-3 Cr) for faster expansion if desired

---

### 16.3 Phase 4: Dominance & Innovation (Months 37+)

**Geographic Expansion:**
- Pan-India presence (50+ cities, Tier 2 focus)
- International pilot (UAE, Singapore — diaspora markets)
- Target: 5,000,000 MAU

**Product Innovation:**
- Private label products (marinades, ready-to-cook)
- Meal kits (recipe ingredients + meat, pre-portioned)
- B2B channel (restaurants, catering)
- Alexa/Google Assistant ordering
- Blockchain traceability (farm-to-fork transparency)
- Drone delivery pilot (select areas, regulatory approval)

**Business Maturity:**
- Category leadership (20%+ market share in operational cities)
- Profitability (EBITDA +10%)
- IPO readiness (₹1,000 Cr+ revenue, audited financials)
- Strategic partnerships (Swiggy integration, BigBasket collaboration)

---

### 16.4 Roadmap Summary Table

| Phase | Timeline | Coverage | MAU | Orders/Month | Key Features | Funding |
|-------|----------|----------|-----|--------------|--------------|---------|
| **Phase 1: MVP** | Months 1-6 | Bokaro (5-10km) | 3-5K | 2-3K | Core app, 30-40min delivery, COD+Online | Bootstrap/₹25-50L |
| **Phase 2: Bokaro Expansion** | Months 7-18 | Bokaro (15-20km) | 12-15K | 8-10K | Referral, reviews, Hindi, 2 stores | Self-funded |
| **Phase 3: Regional** | Months 19-36 | 3 cities (Jharkhand) | 30-40K | 20-25K | Loyalty, WhatsApp, Bengali, profitable | Self-funded/₹2-3Cr |
| **Phase 4: State Level** | Months 37+ | 8-10 cities (Jharkhand+Bihar) | 80-100K | 60-80K | B2B, bulk, private label | Growth capital if needed |

---

## Conclusion

This Product Requirements Document outlines a comprehensive vision for **Meatvo**, a hyperlocal fresh meat and grocery delivery platform designed to disrupt the $30B+ Indian meat market. By combining **Licious's quality-first approach** with **Zepto's speed-to-delivery model**, Meatvo occupies a unique position in the market:

**Key Differentiators:**
1. **30-Minute Delivery:** Fastest in the meat category
2. **Competitive Pricing:** 15-20% cheaper than premium players
3. **Quality Assurance:** FSSAI-certified, QR code traceability
4. **Superior UX:** Modern app, real-time tracking, 24/7 support
5. **Profitable Unit Economics:** LTV:CAC 23.3x, 32% contribution margin

**Path to Success:**
- **Phase 1 (Months 1-6):** Validate product-market fit in Bangalore (10K users, 5K orders/month)
- **Phase 2 (Months 7-18):** Expand to 3 cities, achieve operational excellence (100K users, 50K orders/month)
- **Phase 3 (Months 19-36):** Scale to 10 cities, category leadership (1M users, 500K orders/month, EBITDA positive)

**Investment Opportunity:**
- **Seed (Completed):** $500K — MVP development, pilot launch
- **Series A (Month 12-15):** $3M — Market expansion, tech infrastructure, break-even in launch city
- **Exit Potential:** $200M+ valuation (Year 5), based on Licious trajectory

This PRD provides a complete roadmap for building a **unicorn-trajectory startup** in the rapidly growing online meat delivery space. With strong unit economics, clear differentiation, and a scalable technology platform, Meatvo is positioned to become **India's #1 hyperlocal meat delivery platform**.

---

**Document Approval:**

| Role | Name | Signature | Date |
|------|------|-----------|------|
| **Chief Product Officer** | [Name] | __________ | __________ |
| **CTO** | [Name] | __________ | __________ |
| **CEO** | [Name] | __________ | __________ |

---

**Document Control:**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | June 12, 2026 | CPO Office | Initial comprehensive PRD |

---

*Document Classification: Confidential — Investor & Internal Use Only*  
*Total Word Count: 18,500+ words*  
*Total Pages: 120+ pages*  

**END OF DOCUMENT**

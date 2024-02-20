select * from CovidDeaths
order by 3,4

SELECT * FROM CovidVaccinations ORDER BY 3,4

SELECT location, date, total_cases, new_cases, total_deaths, population
FROM CovidDeaths
ORDER BY 1,2

-- Looking at Total Cases vs Total Deaths
SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS DeathPercentage
FROM CovidDeaths
where location like '%states%'
ORDER BY 1,2

-- Looking at Total Cases vs Population
-- shows what percentage of population has covid
SELECT location, date, population, total_cases, (total_cases/population)*100 AS PercentPopulationInfected
FROM CovidDeaths
--where location like '%states%'
ORDER BY 1,2

--Looking at countries with highest infection rate compared to population
SELECT location, population, MAX(total_cases) AS HighestInfectionCount, 
MAX(total_cases/population)*100 AS PercentPopulationInfected
FROM CovidDeaths
--where location like '%states%'
GROUP BY location, population
ORDER BY PercentPopulationInfected DESC

--Showing Countries with Highest Death Count per Population
SELECT location, MAX(total_deaths) AS TotalDeathCount
FROM CovidDeaths
--where location like '%states%'
WHERE continent is not null --this is added because we got some unwanted results in the query
GROUP BY location
ORDER BY TotalDeathCount DESC


--LET'S BREAK THINGS DOWN BY CONTINENT
SELECT continent, MAX(total_deaths) AS TotalDeathCount
FROM CovidDeaths
--where location like '%states%'
WHERE continent is not null
GROUP BY continent
ORDER BY TotalDeathCount DESC

--Showing the Continent with the Highest Death Count per Population
SELECT continent, MAX(total_deaths) AS TotalDeathCount
FROM CovidDeaths
--where location like '%states%'
WHERE continent is not null
GROUP BY continent
ORDER BY TotalDeathCount DESC

--GLOBAL NUMBERS

SELECT date, SUM(new_cases) as totalcases, SUM(new_deaths) as totaldeaths, 
CASE 
	WHEN SUM(new_cases) is null then null
	WHEN SUM(new_cases) = 0 then 0
	else (SUM(new_deaths)/SUM(new_cases))*100 
END as DeathPercentage
FROM CovidDeaths
--WHERE location like 'Nig%'
where continent is not null
Group by date
ORDER BY 1,2

--Looking at Total Population vs Vaccination 
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
FROM CovidDeaths as dea
join CovidVaccinations vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent is not null
order by 2,3

-- Total Vaccinated People by Location
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(CONVERT(bigint,vac.new_vaccinations)) over (partition by dea.Location) as TotlPeopleVaccinated
FROM CovidDeaths as dea
join CovidVaccinations vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent is not null
order by 2,3

--ORDER BY DATE While partitioning by location
-- This shows cumulative sum of vaccinations of each location by date
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(CONVERT(bigint,vac.new_vaccinations)) over (partition by dea.Location ORDER by dea.date)
AS RollingPeopleVaccinated
FROM CovidDeaths as dea
join CovidVaccinations vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent is not null
order by 2,3

-- USE CTE
With PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated) AS
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) over (partition by dea.location ORDER by dea.location, dea.date) 
as RollingPeopleVaccinated
FROM CovidDeaths as dea
join CovidVaccinations as vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent is not null
--and dea.location = 'Albania'
--and dea.date BETWEEN '2020-01-01' AND '2021-12-30'
)
select *, CAST(RollingPeopleVaccinated as float) / CAST(Population AS FLOAT)*100
from PopvsVac



--TEMP TABLE
DROP TABLE IF EXISTS #PercentPopulationVaccinated

CREATE TABLE #PercentPopulationVaccinated
(Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
RollingPeopleVaccinated numeric)

INSERT INTO #PercentPopulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
,SUM(CONVERT(bigint,vac.new_vaccinations)) over (partition by dea.location ORDER by dea.location, dea.date) 
as RollingPeopleVaccinated
FROM CovidDeaths as dea
join CovidVaccinations as vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent is not null


select *, CAST(RollingPeopleVaccinated as float) / CAST(Population AS FLOAT)*100
from #PercentPopulationVaccinated
ORDER BY 2,3


--CREATE VIEW TO STORE DATA FOR LATER VISUALIZATION
CREATE VIEW PercentPopulationVaccinated AS
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(CONVERT(bigint, new_vaccinations)) OVER (Partition by dea.location order by dea.location, dea.date)
	AS RollingPeopleVaccinated
FROM CovidDeaths AS dea
	JOIN CovidVaccinations as vac
	ON dea.location = vac.location
	AND dea.date = vac.date
WHERE dea.continent is not null

select *
FROM PercentPopulationVaccinated
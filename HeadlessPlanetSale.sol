//	headless planet sale
//	https://urbit.live

pragma solidity 0.4.24;

import './Ecliptic.sol';

import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import 'openzeppelin-solidity/contracts/lifecycle/Destructible.sol';

//	HeadlessPlanetSale: headless sales of Urbit planets
//
contract HeadlessPlanetSale is Ownable, Destructible
{
	//  PlanetSold: planet has been sold
	//
	event PlanetSold(uint32 indexed prefix, uint32 indexed planet);

	//	azimuth: points state data store
	//
	Azimuth public azimuth;

	//	price: ether per planet, in wei
	//
	uint256 public price;

	//	lastSpawnedPoint: Azimuth point of the planet most recently spawned by the contract 
	//
	uint32 public lastSpawnedPoint;

	//	constructor(): configure the points data store, initial sale price, and Azimuth point of the spawning star
	//
	constructor(Azimuth _azimuth, 
							uint256 _price,
							uint32 _spawningPoint)
		public
	{
		require(	(_spawningPoint < 0x10000) &&
							(_spawningPoint >= 0x100)	);
		setAzimuth(_azimuth);
		setPrice(_price);
		lastSpawnedPoint = _spawningPoint;
	}

	//	(): fallback function spawns the next available planet
	//
	function() 
		external 
		payable 
	{
		//	caller must pay exactly the price of a planet
		//
		require(msg.value == price);

		//	determine the spawn candidate's Azimuth point
		//
		uint32 planet = lastSpawnedPoint + 0x10000;

		//	the spawn candidate's point must be less than the maximum Azimuth point
		//	and the planet must be available for purchase
		//
		require(	(planet < 0x100000000) &&
							available(planet)	);

		//	spawn the planet to us, then immediately transfer to the caller
		//
		//		spawning to the caller would give the point's prefix's owner
		//		a window of opportunity to cancel the transfer
		//
		Ecliptic ecliptic = Ecliptic(azimuth.owner());
		ecliptic.spawn(planet, this);
		ecliptic.transferPoint(planet, msg.sender, false);

		//	update lastSpawnedPoint to the Azimuth point of the planet that was just spawned
		//
		lastSpawnedPoint = planet;

		emit PlanetSold(azimuth.getPrefix(planet), planet);
	}

	//	available(): returns true if the _planet is available for purchase
	//
	function available(uint32 _planet)
		public
		view
		returns (bool result)
	{
		uint16 prefix = azimuth.getPrefix(_planet);

		return (	//	planet must not have an owner yet
							//
							azimuth.isOwner(_planet, 0x0) &&
							//
							//	this contract must be allowed to spawn for the prefix
							//
							azimuth.isSpawnProxy(prefix, this) &&
							//
							//	prefix must be linked
							//
							azimuth.hasBeenLinked(prefix)	);
	}

	//	setAzimuth(): set Azimuth contract address
	//
	function setAzimuth(Azimuth _azimuth)
		public
		onlyOwner
	{
		azimuth = _azimuth;
	}

	//	setPrice(): configure the price in wei per planet
	//
	function setPrice(uint256 _price)
		public
		onlyOwner
	{
		require(0 < _price);
		price = _price;
	}

	//	withdraw(): withdraw ether funds held by this contract to _target
	//
	function withdraw(address _target)
		external
		onlyOwner
	{
		require(0x0 != _target);
		_target.transfer(address(this).balance);
	}
}
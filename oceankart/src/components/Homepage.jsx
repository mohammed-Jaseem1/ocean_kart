import React from 'react';
import './Homepage.css';
import homeScreenImg from '../assets/images/HomeScreen.png';

const Homepage = () => {
  return (
    <div className="homepage-container">
      <img 
        src={homeScreenImg} 
        alt="OceanKart Home" 
        className="home-image" 
      />
    </div>
  );
};

export default Homepage;


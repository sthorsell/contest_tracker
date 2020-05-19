import React, { Component, useEffect } from "react";
import {ArrowBackIos, ArrowForwardIos} from '@material-ui/icons';
import { AppBar, CssBaseline, Toolbar, Typography, Select, MenuItem, Grid, Slider, IconButton, makeStyles } from '@material-ui/core'


import Contest from './Contest'
import EntriesTable from './EntriesTable'

const useStyles = makeStyles(() => ({
  root: {
    paddingLeft: '16px',
    paddingRight: '16px'
  },
  marked: {
    marginBottom: '0px'
  }
}));

export default function Root() {
  const [quarter, setQuarter] = React.useState(1);
  const [selectedPlay, setSelectedPlay] = React.useState(0);
  const [plays, setPlays] = React.useState([]);
  const [filteredPlays, setFilteredPlays] = React.useState([]);
  const [maxPlayIndex, setMaxPlayIndex] = React.useState(0);
  const [entries, setEntries] = React.useState([]);
  const [entryPage, setEntryPage] = React.useState(0);
  const [sliderMarks, setSliderMarks] = React.useState([]);
  const classes = useStyles();

  useEffect(() => {
    fetch('api/plays')
      .then(response => response.json())
      .then(data => {
        setPlays(data);
        const filtered = data.filter(p => p.quarter === quarter);
        setFilteredPlays(filtered);
      });
  }, []);

  useEffect(() => {
    setFilteredPlays(plays.filter(p => p.quarter === quarter))
  }, [quarter]);

  const handleChange = (event) => {
    setQuarter(event.target.value);
  };

  useEffect(() => {
    setEntryPage(0)
  }, [selectedPlay]);

  useEffect(() => {
    setSelectedPlay(0);
  }, [quarter]);

  useEffect(() => {
    setMaxPlayIndex(filteredPlays.length - 1);

    const marks = filteredPlays.reduce((res, play, i) => {
      if(['FG', 'TD'].includes(play.note)){
        res.push({value: i, label: play.note});
      }
      return res;
    }, []);
    setSliderMarks(marks);
  }, [filteredPlays]);

  useEffect(() => {
    const play = filteredPlays[selectedPlay]
    if(play){
      fetch(`api/entries/${play.id}/${entryPage}`)
        .then(response => response.json())
        .then(data => {
          setEntries(data)
        })
    }
  }, [entryPage, selectedPlay, filteredPlays])

  return(
    <div>
      <CssBaseline />
      <AppBar position="static">
        <Toolbar>
          <Typography variant="h6">
              Contest Tracker
          </Typography>
        </Toolbar>
      </AppBar>
      <Grid container className={classes.root} direction="row" justify="center">
        <Contest />
        <Grid item xs={4} align="left">
          <Select
            labelId="quarter-label"
            id="quarter"
            value={quarter}
            onChange={handleChange}
          >
            {[1,2,3,4].map(i => (
              <MenuItem value={i} key={i}>Quarter {i}</MenuItem>
            ))}
          </Select>
        </Grid>
        <Grid item xs={4}>
          <Typography variant="h6" align="center" gutterBottom>
            Chiefs: {filteredPlays[selectedPlay] ? filteredPlays[selectedPlay].score.home : 0}
          </Typography>
        </Grid>
        <Grid item xs={4}>
          <Typography variant="h6" align="right" gutterBottom>
            49ers: {filteredPlays[selectedPlay] ? filteredPlays[selectedPlay].score.away : 0}
          </Typography>
        </Grid>
      </Grid>

      <Grid item xs={12} className={classes.root} >
        <Typography variant="body2" gutterBottom style={{minHeight: "78px"}}>
          {filteredPlays[selectedPlay] ? filteredPlays[selectedPlay].description : 'Loading...'}
        </Typography>
      </Grid>

      <Grid container direction="row" justify="center" alignItems="center" style={{paddingBottom: '8px'}}>
        <Grid item xs={2} align="center">
          <IconButton aria-label="previous play" disabled={selectedPlay === 0} onClick={() => setSelectedPlay(play => play - 1)} style={{paddingTop: '8px'}}>
            <ArrowBackIos />
          </IconButton>
        </Grid>
        <Grid item xs={8}>
          <Slider
            value={selectedPlay}
            aria-labelledby="discrete-slider-small-steps"
            classes={{marked: classes.marked}}
            step={1}
            marks={sliderMarks}
            min={0}
            max={maxPlayIndex}
            onChange={(_, i) =>  setSelectedPlay(i) }
            valueLabelDisplay="off"
          />
        </Grid>
        <Grid item xs={2} align="center">
          <IconButton aria-label="previous play" disabled={maxPlayIndex === selectedPlay} onClick={() => setSelectedPlay(play => play + 1)} style={{paddingTop: '8px'}}>
            <ArrowForwardIos />
          </IconButton>
        </Grid>
      </Grid>

      <EntriesTable entries={entries} entryPage={entryPage} onChangePage={setEntryPage} />
    </div>
  );
}
